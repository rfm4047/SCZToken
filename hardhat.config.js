// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.20",
  networks: {
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [process.env.PRIVATE_KEY]
    },
    avalanche: { // ✅ Agregar esta sección
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY, // Nombre EXACTO requerido
      avalanche: process.env.SNOWTRACE_MAINNET_API_KEY,
    },
    customChains: [
      {
        network: "avalancheFujiTestnet", // Debe coincidir con el nombre en apiKey
        chainId: 43113,
        urls: {
          apiURL: "https://api-testnet.snowtrace.io/api", // Endpoint actualizado
          browserURL: "https://testnet.snowtrace.io"
        }
      },
        {
          network: "avalanche",
          chainId: 43114,
          urls: {
            apiURL: "https://api.snowtrace.io/api",
            browserURL: "https://snowtrace.io"
          }
        }
    ]
  }
};