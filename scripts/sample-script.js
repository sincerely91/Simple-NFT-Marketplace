const hre = require("hardhat");

async function main() {
  const Market = await hre.ethers.getContractFactory("Market");
  const market = await Market.deploy("Hello, Hardhat!");
  await market.deployed();
  console.log("Market deployed to:", market.address);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
