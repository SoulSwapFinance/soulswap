require('babel-register');
require('babel-polyfill');
require('dotenv').config();
const HDWalletProvider = require('truffle-hdwallet-provider-privkey');
const privateKeys = process.env.PRIVATE_KEYS || ""

module.exports = {
  networks: {
      development: {
        host: "127.0.0.1",
        port: 8020,
        network_id: "*"
      },
      testnet: {
        provider: function() {
          return new HDWalletProvider(
            privateKeys.split(','), // Array of account private keys
            )
            //`https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`// URL to an Ethereum Node
            `http://rpc.testnet.fantom.network`// URL to an Ethereum Node
        },
        gas: 5000000,
        gasPrice: 25000000000,
        network_id: 4002
      },
      fantom: {
        provider: function() {
          return new HDWalletProvider(
            privateKeys.split(','), // Array of account private keys
            )
            //`https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`// URL to an Ethereum Node
            `https://rpc.fantom.tools`// URL to an Ethereum Node
        },
        gas: 5000000,
        gasPrice: 25000000000,
        network_id: 250
      }
    },
    plugins: [
      'truffle-plugin-verify'
    ],
    api_keys: {
      etherscan: process.env.ETHERSCAN_API_KEY
    },
    compilers: {
      solc: {
        version: "0.8.0"
      }
    }
};
