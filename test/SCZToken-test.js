const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SCZToken - Funcionalidades Adicionales", function () {
  let SCZToken, token, deployer, user, user2;
  let addresses, params;
  let MockCreditOracle, creditOracle;

  // Variables para propiedades: Valor reducido a 1,000 USDT para que el pago sea razonable.
  const propertyId = 1;
  const propertyValue = ethers.parseUnits("1000", 18); // Valor del inmueble: 1,000 USDT

  beforeEach(async function () {
    // Obtener cuentas de prueba
    [deployer, user, user2] = await ethers.getSigners();

    // Configuramos el array de direcciones:
    // Usamos deployer, user, user2 y duplicamos para marketing y reserve.
    addresses = [
      deployer.address, // preSaleWallet
      user.address,     // liquidityWallet
      user2.address,    // teamWallet
      user.address,     // marketingWallet
      user2.address     // reserveWallet
    ];

    // Parámetros de preventa: [softCap, hardCap, tokenPrice, preSaleStart, preSaleEnd, minPurchase, maxPurchase]
    params = [
      ethers.parseUnits("50000", 18), // softCap: 50,000 USDT
      ethers.parseUnits("100000", 18), // hardCap: 100,000 USDT
      ethers.parseUnits("0.03", 18),   // tokenPrice: 0.03 USDT
      Math.floor(new Date("2025-03-05T00:00:00Z").getTime() / 1000), // preSaleStart
      Math.floor(new Date("2025-03-25T00:00:00Z").getTime() / 1000), // preSaleEnd
      ethers.parseUnits("10", 18),     // minPurchase: 10 USDT
      ethers.parseUnits("5000", 18)    // maxPurchase: 5,000 USDT
    ];

    // Desplegar el contrato SCZToken
    SCZToken = await ethers.getContractFactory("SCZToken");
    token = await SCZToken.deploy(addresses, params);
    await token.waitForDeployment();

    // Desplegar el oráculo de crédito mock
    const MockCreditOracleFactory = await ethers.getContractFactory("MockCreditOracle");
    creditOracle = await MockCreditOracleFactory.deploy();
    await creditOracle.waitForDeployment();

    // Configurar el oráculo en el contrato SCZToken: umbral de 700 (por ejemplo)
    await token.setCreditOracle(creditOracle.getAddress(), 700);

    // Establecer un valor para el inmueble
    await token.updatePropertyValue(propertyId, propertyValue);
  });

  describe("Compra de Fracción", function () {
    it("Debe permitir comprar una fracción si se envía el pago correcto", async function () {
      // Supongamos que el usuario compra el 10% de la propiedad.
      const fraction = 10;
      // Calcular requiredPayment como: (propertyValue * fraction) / 100, usando BigInt
      const requiredPayment = propertyValue * BigInt(fraction) / 100n;

      // user realiza la compra con el pago correcto
      await expect(
        token.connect(user).buyFraction(propertyId, fraction, { value: requiredPayment })
      )
        .to.emit(token, "FractionBought")
        .withArgs(propertyId, user.address, fraction, requiredPayment);

      // Verificar que se registró la fracción comprada
      expect(await token.propertyFractions(propertyId, user.address)).to.equal(fraction);
    });

    it("Debe revertir la compra de fracción si el pago es insuficiente", async function () {
      const fraction = 20;
      // Aseguramos el uso de BigInt para operaciones
      const requiredPayment = propertyValue * BigInt(fraction) / 100n;
      // Enviar menos valor (restamos 1n)
      await expect(
        token.connect(user).buyFraction(propertyId, fraction, { value: requiredPayment - 1n })
      ).to.be.revertedWith("Insufficient payment");
    });
  });

  describe("Solicitud de Crédito con Inmueble", function () {
    it("Debe revertir la solicitud de crédito si el usuario no posee fracción", async function () {
      // Asegurarse que user2 no posee fracción en la propiedad
      await expect(
        token.connect(user2).requestCreditWithRealEstate(propertyId, ethers.parseUnits("1000", 18))
      ).to.be.revertedWith("No fraction owned");
    });

    it("Debe revertir la solicitud de crédito si el historial crediticio no es excelente", async function () {
      // user compra una fracción para tener propiedad
      const fraction = 15;
      const requiredPayment = propertyValue * BigInt(fraction) / 100n;
      await token.connect(user).buyFraction(propertyId, fraction, { value: requiredPayment });

      // Simular mal historial crediticio: establecer puntaje menor al umbral (700)
      await creditOracle.setScore(600);

      await expect(
        token.connect(user).requestCreditWithRealEstate(propertyId, ethers.parseUnits("1000", 18))
      ).to.be.revertedWith("Credit history not excellent");
    });

    it("Debe permitir solicitar crédito si posee fracción, tiene KYC y excelente historial (via oráculo)", async function () {
      // user compra una fracción del 20%
      const fraction = 20;
      const requiredPayment = propertyValue * BigInt(fraction) / 100n;
      await token.connect(user).buyFraction(propertyId, fraction, { value: requiredPayment });
      
      // Verificar KYC para user
      await token.verifyKYC(user.address);
      // Simular excelente historial: puntaje >= 700
      await creditOracle.setScore(750);

      // Calcular el crédito máximo permitido: (propertyValue * fraction / 100)
      const maxCredit = propertyValue * BigInt(fraction) / 100n;
      // Solicitar un crédito inferior a maxCredit
      const creditAmount = ethers.parseUnits("150", 18); // 150 USDT
      const tx = await token.connect(user).requestCreditWithRealEstate(propertyId, creditAmount);
      await tx.wait();
      // Comprobar que se creó el préstamo
      const loan = await token.loans(0);
      expect(loan.borrower).to.equal(user.address);
      expect(loan.amount).to.equal(creditAmount);
    });
  });

  describe("Pagos Parciales y Refinanciamiento", function () {
    it("Debe permitir pagos parciales y refinanciamiento si se cumple el 75% pagado", async function () {
      // Verificar KYC para user
      await token.verifyKYC(user.address);

      // Solicitar un préstamo sin colateral de 1000 USDT
      const creditAmount = ethers.parseUnits("1000", 18);
      const txLoan = await token.connect(user).requestCreditWithoutCollateral(creditAmount);
      await txLoan.wait();
      // Asumimos que el préstamo tiene loanId = 0

      // Realizar un pago parcial del 75%
      const partialPayment = (creditAmount * 75n) / 100n;
      await token.connect(user).partialRepayLoan(0, partialPayment);

      // Refinanciar el préstamo
      const txRefi = await token.connect(user).refinanceLoan(0);
      await txRefi.wait();

      const loan = await token.loans(0);
      expect(loan.dueDate).to.be.above((await ethers.provider.getBlock("latest")).timestamp);
      // La tasa de interés debe haber disminuido en 2 (si era mayor a 2)
      expect(loan.interestRate).to.be.lt(10);
    });
  });
});
