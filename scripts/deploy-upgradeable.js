const { ethers, upgrades } = require("hardhat");

async function main() {
  const SCZTokenUpgradeable = await ethers.getContractFactory("SCZTokenUpgradeable");
  console.log("Desplegando SCZTokenUpgradeable...");

  // Desplegar el proxy, pasando un arreglo vacío [] porque initialize no recibe argumentos
  const token = await upgrades.deployProxy(SCZTokenUpgradeable, [], { initializer: "initialize" });
  await token.waitForDeployment();

  // En ethers v6 se usa getAddress() en lugar de la propiedad address
  const tokenAddress = await token.getAddress();
  console.log("SCZTokenUpgradeable desplegado en:", tokenAddress);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
