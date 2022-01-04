// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

contract Market is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemsCancelled;
    address payable owner;
    uint256 listingPrice = 0.025 ether;

    enum MarketItemStatus {
        Active,
        Sold,
        Cancelled
    }

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        MarketItemStatus status;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );
    event MarketItemCancelled(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        _itemIds.increment();

        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            MarketItemStatus.Active
        );

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            MarketItemStatus.Active
        );
    }

    function createMarketSale(address nftContract, uint256 itemId)
        external
        payable
        nonReentrant
    {
        MarketItem storage idToMarketItem_ = idToMarketItem[itemId];
        uint256 tokenId = idToMarketItem_.tokenId;
        require(
            idToMarketItem_.status == MarketItemStatus.Active,
            "Listing Not Active"
        );
        require(msg.sender != idToMarketItem_.seller, "Seller can't be buyer");
        require(
            msg.value == idToMarketItem_.price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToMarketItem_.seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem_.owner = payable(msg.sender);
        idToMarketItem_.status = MarketItemStatus.Sold;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);

        emit MarketItemSold(
            itemId,
            nftContract,
            tokenId,
            idToMarketItem_.seller,
            msg.sender,
            idToMarketItem_.price,
            idToMarketItem_.status
        );
    }

    function cancelMarketItem(address nftContract, uint256 itemId)
        external
        nonReentrant
    {
        MarketItem storage idToMarketItem_ = idToMarketItem[itemId];
        require(msg.sender == idToMarketItem_.seller, "Only Seller can Cancel");
        require(
            idToMarketItem_.status == MarketItemStatus.Active,
            "Item must be active"
        );
        idToMarketItem_.status == MarketItemStatus.Cancelled;
        _itemsCancelled.increment();
        idToMarketItem_.seller.transfer(listingPrice);
        IERC721(nftContract).transferFrom(
            address(this),
            msg.sender,
            idToMarketItem_.tokenId
        );

        emit MarketItemCreated(
            itemId,
            nftContract,
            idToMarketItem_.tokenId,
            idToMarketItem_.seller,
            address(0),
            idToMarketItem_.price,
            MarketItemStatus.Cancelled
        );
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() -
            _itemsSold.current() -
            _itemsCancelled.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].status == MarketItemStatus.Active) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToMarketItem[i + 1].seller == msg.sender &&
                idToMarketItem[i + 1].status != MarketItemStatus.Cancelled
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToMarketItem[i + 1].seller == msg.sender &&
                idToMarketItem[i + 1].status != MarketItemStatus.Cancelled
            ) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
