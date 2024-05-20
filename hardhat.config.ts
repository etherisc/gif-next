import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import "solidity-docgen";

// load .env file 
import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

const { TENDERLY_PRIVATE_VERIFICATION, TENDERLY_AUTOMATIC_VERIFICATION } =
  process.env;

const privateVerification = TENDERLY_PRIVATE_VERIFICATION === "true";
const automaticVerifications = TENDERLY_AUTOMATIC_VERIFICATION === "true";// TODO use default false value -> no automatic verification

import * as tenderly from "@tenderly/hardhat-tenderly";

tenderly.setup({ automaticVerifications });

console.log("Using private verification?", privateVerification);
console.log("Using automatic verification?", automaticVerifications);


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
  tenderly: {
    username: process.env.TENDERLY_USERNAME,
    project: process.env.TENDERLY_PROJECT,
    privateVerification: privateVerification,
  },
  docgen: require("./docs/config"),
  networks: {
    hardhat: {
    },
    anvil: {
      chainId: 1337,
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
    virtualMainnet: {
      url: process.env.TENDERLY_DEVNET_RPC_URL,
      chainId: 1
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    },
  },
};

export default config;
