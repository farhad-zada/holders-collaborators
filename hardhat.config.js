require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
      },
    ],
  },
  defaultNetwork: "hardhat",

  networks: {
    hardhat: {
      chainId: 1337,
    },
    bsc: {
      url: process.env.BSC_RPC,
      chainId: process.env.BSC_CID * 1,
      accounts: [process.env.PKEY],
    },
    pol: {
      url: process.env.POL_RPC,
      chainId: process.env.POL_CID * 1,
      accounts: [process.env.PKEY],
    },
    sep: {
      url: process.env.SEP_RPC,
      chainId: process.env.SEP_CID * 1,
      accounts: [process.env.PKEY],
    },
    tbsc: {
      url: process.env.TEST_BSC_RPC,
      chainId: process.env.TEST_BSC_CID * 1,
      accounts: [process.env.PKEY],
    },
    tpol: {
      url: process.env.TEST_POL_RPC,
      chainId: process.env.TEST_POL_CID * 1,
      accounts: [process.env.PKEY],
    },
    eth: {
      url: process.env.ETH_RPC,
      chainId: process.env.ETH_CID * 1,
      accounts: [process.env.PKEY],
    },
  },

  etherscan: {
    apiKey: {
      eth: process.env.ETH_APIKEY,
      bsc: process.env.BSC_APIKEY,
      pol: process.env.POL_APIKEY,
    },
  },
};
