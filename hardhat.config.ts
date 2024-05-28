import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import "solidity-docgen";

// load .env file 
import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

const config: HardhatUserConfig = {
  ignition: {
    strategyConfig: {
        create2: {
            salt: "0x0000000000000000000000000000000000000000000000000000000000000004",
        }
    }
  },
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: 'paris',
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  docgen: require("./docs/config"),
  networks: {
    hardhat: {
    },
    anvil: {
      chainId: 1337,
      url: "http://anvil:7545",
      accounts: {
        mnemonic: process.env.WALLET_MNEMONIC || "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
        count: 20,
      },
    },
    polygonAmoy: {
      chainId: 80002,
      url: process.env.NETWORK_URL || 'https://rpc-amoy.polygon.technology/',
      accounts: {
        mnemonic: process.env.WALLET_MNEMONIC || "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
        count: 20,
      },
    },
    mainnet: {
      chainId: 1,
      url: process.env.NETWORK_URL || 'https://mainnet.infura.io/v3/' + process.env.WEB3_INFURA_PROJECT_ID,
    },
  },
  etherscan: {
    apiKey: {
      polygonAmoy:  process.env.POLYGONSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        },
      }
    ]
  },
};

export default config;
