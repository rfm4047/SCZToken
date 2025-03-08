// scripts/mint.js
const { ethers } = require("hardhat");

async function main() {
  // Dirección del contrato token
  const tokenAddress = "0xEF9bA5C90D2aAf58Dc2778B37F8970e76ef362e5";
  // Dirección del destinatario de los nuevos tokens (puede ser la misma cuenta o una diferente)
  const recipient = "0xf2e2f202A6D4cc7dD7748E9B6426df56A04cc2E1"; // Reemplaza con la dirección deseada
  // Cantidad de tokens a acuñar (ejemplo: 1000 tokens, ajusta según los decimales del token)
  const mintAmount = ethers.parseUnits("1000", 18);


  // Obtener instancia del contrato usando el nombre de la interfaz (asegúrate de que coincida con tu contrato)
  const Token = await ethers.getContractAt("SCZToken", tokenAddress);

  console.log("Ejecutando mint para aumentar tokens...");

  // Llamada a la función mint; esta operación requiere permisos
  const tx = await Token.mint(recipient, mintAmount);
  await tx.wait();

  console.log("Tokens acuñados exitosamente!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error en la ejecución del script:", error);
    process.exit(1);
  });
