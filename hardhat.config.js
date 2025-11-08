require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20000,
      },
      viaIR: false,
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      allowUnlimitedContractSize: true,
    },
  },
  gasReporter: {
    enabled: false,
  },
};
