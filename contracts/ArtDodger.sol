// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2981Royalties.sol";
import "hardhat/console.sol";

contract ArtDodger is Ownable, ERC721URIStorage, ERC2981Royalties {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Art Dodger", "ARTD") {}

    function mintNft(
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyPercent
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        if (royaltyPercent > 0) {
            _setTokenRoyalty(newItemId, royaltyRecipient, royaltyPercent);
        }
        return newItemId;
    }
}
