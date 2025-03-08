const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Desplegando con la cuenta:", deployer.address);

  // Array de direcciones (reemplaza con direcciones reales)
  const addresses = [
    "0x60d4A409c025E9c792D7EdF8398A9F9a3DDF44DB",    // preSaleWallet
    "0x9fa413463F59E7D6d01B379c34FF01a60628e21a",   // liquidityWallet
    "0x453E850135aAAa3f82C541fe2D32ed2303697f79",        // teamWallet
    "0x8595e479B9931BAe04ce8489101e2482E00C5575",   // marketingWallet
    "0xEF9bA5C90D2aAf58Dc2778B37F8970e76ef362e5"      // reserveWallet
  ];

  // Array de parámetros: [softCap, hardCap, tokenPrice, preSaleStart, preSaleEnd, minPurchase, maxPurchase]
  const params = [
    ethers.parseUnits("50000", 18),                      // softCap: 50,000 USDT
    ethers.parseUnits("100000", 18),                     // hardCap: 100,000 USDT
    ethers.parseUnits("0.03", 18),                       // tokenPrice: 0.03 USDT
    Math.floor(new Date("2025-03-05T00:00:00Z").getTime() / 1000), // preSaleStart
    Math.floor(new Date("2025-03-25T00:00:00Z").getTime() / 1000), // preSaleEnd
    ethers.parseUnits("10", 18),                         // minPurchase: 10 USDT
    ethers.parseUnits("5000", 18)                        // maxPurchase: 5,000 USDT
  ];

  const SCZToken = await ethers.getContractFactory("SCZToken");
  const token = await SCZToken.deploy(addresses, params);
  await token.waitForDeployment();
  console.log("SCZToken desplegado en:", await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
