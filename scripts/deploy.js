const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
  const ArtDodger = await ethers.getContractFactory("ArtDodger");
  const artDodger = await ArtDodger.deploy();
  await artDodger.deployed();

  const ArtDMarketplace = await ethers.getContractFactory("ArtDMarketplace");
  const artDMarketplace = await ArtDMarketplace.deploy(artDodger.address);
  await artDMarketplace.deployed();

  let config = `
  export const ArtDMarketplace = "${artDMarketplace.address}"
  export const ArtDodger = "${artDodger.address}"
  `
  fs.writeFileSync('config.js', config)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });