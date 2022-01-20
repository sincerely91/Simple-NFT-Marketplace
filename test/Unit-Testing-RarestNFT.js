const { expect } = require('chai')
const { ethers } = require("hardhat");
describe("RarestNFT", async () => {
    let rarestnft;
    let marketAddress;
    let rarestAddress;
    const baseURI = 'https://gateway.pinata.cloud/ipfs/';
    before(async () => {
        const Market = await ethers.getContractFactory('ERC1155Market');
        const market = await Market.deploy();
        await market.deployed();
        marketAddress = market.address;
    })
    beforeEach(async () => {
        const RarestNFT = await ethers.getContractFactory("RarestNFT");
        rarestnft = await RarestNFT.deploy(marketAddress);
        await rarestnft.deployed();
    });


    it("Is BOTH market and nft contract deployed", async () => {
        rarestAddress = rarestnft.address;
        expect(rarestAddress).to.be.not.undefined;
        expect(rarestAddress).to.be.not.null;
    })

    it("CreateNFT and get", async () => {
        let [recipient] = await ethers.provider.listAccounts();
        let amount = 20;
        let hash = '0xRajkumar';
        var data = '0x10';
        let royaltyRecipient = recipient;
        let royaltyPercent = 10;
        const returnTokenID = await rarestnft.createNFT(recipient, amount, hash, data, royaltyRecipient, royaltyPercent)
        const Id = await returnTokenID.wait();
        const tokenId = parseInt(Id.events[1].data, 16);

        //Return tokenId which should be equal to one 
        expect(tokenId).to.be.not.undefined;
        expect(tokenId).to.be.not.null;
        expect(tokenId).to.equal(1);

        //Return balance must be equal to Amount
        const getNFT = await rarestnft.balanceOf(recipient, tokenId);
        expect(getNFT.toNumber()).to.equal(amount);
    })

    it("Marketplace should be approved for all", async () => {
        let [recipient] = await ethers.provider.listAccounts();
        let amount = 20;
        let hash = 'HASH';
        var data = '0x10';
        let royaltyRecipient = recipient;
        let royaltyPercent = 10;
        await rarestnft.createNFT(recipient, amount, hash, data, royaltyRecipient, royaltyPercent)
        const approval = await rarestnft.isApprovedForAll(recipient, marketAddress)
        expect(approval).to.equal(true)
    })
    it("Getting Right URI ", async () => {
        let [recipient] = await ethers.provider.listAccounts();
        let amount = 20;
        let hash = 'HASH';
        var data = '0x10';
        let royaltyRecipient = recipient;
        let royaltyPercent = 10;
        const returnTokenID = await rarestnft.createNFT(recipient, amount, hash, data, royaltyRecipient, royaltyPercent)
        const Id = await returnTokenID.wait();
        const tokenId = parseInt(Id.events[1].data, 16);
        const uri = await rarestnft.uri(tokenId)
        expect(uri).to.equal(baseURI + hash)
    })
})