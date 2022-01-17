require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const INFURA_KEY = process.env.INFURA_KEY
const PRIVATE_KEY = process.env.PRIVATE_KEY
const API_KEY = process.env.API_KEY
module.exports = {
  defaultNetwork: "ropsten",
  solidity: "0.8.9",
  networks: {
    hardhat: {
      chainId: 1337
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
  },
  etherscan: {
    apiKey: API_KEY
  }
}
