// scripts/deploy.js
require("@nomiclabs/hardhat-ethers");

async function main() {
	const VaultToCurve = await ethers.getContractFactory("VaultToCurve");
	console.log("Deploying ...");
	const box = await VaultToCurve.deploy();
	console.log("VaultToCurve deployed to:", box.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
