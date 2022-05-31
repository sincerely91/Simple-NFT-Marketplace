const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
  const ArtDMarketplace = await ethers.getContractFactory("ArtDMarketplace");
  const artDMarketplace = await ArtDMarketplace.deploy();
  await artDMarketplace.deployed();

  const ArtDodger = await ethers.getContractFactory("ArtDodger");
  const artDodger = await ArtDodger.deploy(artDMarketplace.address);
  await artDodger.deployed();

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