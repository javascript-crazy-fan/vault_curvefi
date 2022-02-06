// hardhat.config.js
const { alchemyApiKey, mnemonic, apiKey, infuraKey } = require("./secrets.json");

require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	solidity: {
		version: "0.8.10",
		settings: {
			optimizer: {
				enabled: true,
				runs: 1000,
			},
		},
	},
	networks: {
		kovan: {
			url: `https://eth-kovan.alchemyapi.io/v2/${alchemyApiKey}`,
			accounts: { mnemonic: mnemonic },
		},
		rinkeby: {
			url: "https://rinkeby.infura.io/v3/" + infuraKey,
			gas: 10000000,
			accounts: { mnemonic: mnemonic },
		},
		testnet: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
		mainnet: {
			url: "https://bsc-dataseed.binance.org/",
			chainId: 56,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic },
		},
	},
	etherscan: {
		// Your API key for Etherscan
		// Obtain one at https://etherscan.io/
		// apiKey: BSCSCAN_API_KEY,
		apiKey: apiKey,
	},
};
