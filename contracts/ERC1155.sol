// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RarestNFT is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseURI = "https://gateway.pinata.cloud/ipfs/";
    mapping(uint256 => string) private _hashes;

    constructor() ERC1155("") {}

    function createNFT(
        address recipient,
        uint256 amount,
        string memory hash,
        bytes memory data
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId, amount, data);
        _hashes[newTokenId] = hash;
        return newTokenId;
    }

    function creatNFTBatch(
        address recipient,
        uint256[] memory amounts,
        string[] memory hashes,
        bytes memory data
    ) public returns (uint256[] memory) {
        require(
            amounts.length == hashes.length,
            "amount must be equal to hash"
        );
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _hashes[newTokenId] = hashes[i];
            ids[i] = newTokenId;
        }
        _mintBatch(recipient, ids, amounts, data);
        return ids;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, _hashes[tokenId]));
    }
}
