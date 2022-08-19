// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2981Royalties.sol";
import "hardhat/console.sol";

contract ArtDodger is Ownable, ERC721Enumerable, ERC2981Royalties {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseURI = "https://gateway.pinata.cloud/ipfs/";
    mapping(uint256 => string) private _hashes;

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function uri(uint256 tokenId) public view returns (string memory) {
        return string(abi.encodePacked(baseURI, _hashes[tokenId]));
    }

    constructor() ERC721("Art Dodger", "ARTD") {}

    function mintNft(
        string memory tokenURI_,
        address royaltyRecipient,
        uint256 royaltyPercent
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _hashes[newItemId] = tokenURI_;
        if (royaltyPercent > 0) {
            _setTokenRoyalty(newItemId, royaltyRecipient, royaltyPercent);
        }
        return newItemId;
    }

    function ownerTokenIds(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(owner);
        require(balance > 0, "Owner dont have tokens");
        uint256[] memory result = new uint256[](balance);
        for (uint256 i; i < balance; i++) {
            result[i] = tokenOfOwnerByIndex(owner, i);
        }
        return result;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
