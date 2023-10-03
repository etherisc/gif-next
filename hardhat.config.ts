import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";

// load .env file 
import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

const config: HardhatUserConfig = {
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
  networks: {
    hardhat: {
    },
    anvil: {
      url: "http://anvil:7545",
      accounts: {
        mnemonic: "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
        count: 20,
      },
    },
    mumbai: {
      chainId: 80001,
      gasPrice: 3100000000,
      url: process.env.NETWORK_URL || 'https://polygon-mumbai.infura.io/v3/' + process.env.WEB3_INFURA_PROJECT_ID,
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
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    },
  },
};

export default config;
