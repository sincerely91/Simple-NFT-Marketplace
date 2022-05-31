// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ArtDodger.sol";

contract ArtDMarketplace is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemsCancelled;
    uint256 listingPrice = 5000000000000000;
    ArtDodger private artD;

    enum MarketItemStatus {
        Active,
        Sold,
        Cancelled
    }

    constructor() {
        artD = ArtDodger(address(0));
    }

    function setArtD(address ArtDAddress) public onlyOwner returns (bool) {
        artD = ArtDodger(ArtDAddress);
        return true;
    }

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        MarketItemStatus status;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );

    event MarketItemCancelled(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );

    event MarketItemSold(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        MarketItemStatus status
    );

    modifier OnlyItemOwner(uint256 tokenId) {
        require(
            artD.ownerOf(tokenId) == msg.sender,
            "Sender does not own the item"
        );
        _;
    }

    modifier HasTransferApproval(uint256 tokenId) {
        require(
            artD.getApproved(tokenId) == address(this),
            "Market is not approved"
        );
        _;
    }

    modifier ItemExists(uint256 id) {
        require(id <= _itemIds.current() && id > 0, "Could not find item");
        _;
    }

    function changeListingPrice(uint256 price) public onlyOwner returns (bool) {
        listingPrice = price;
        return true;
    }

    function createMarketItem(uint256 tokenId, uint256 price)
        external
        payable
        OnlyItemOwner(tokenId)
        HasTransferApproval(tokenId)
    {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        artD.transferFrom(msg.sender, address(this), tokenId);

        _itemIds.increment();

        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            MarketItemStatus.Active
        );

        emit MarketItemCreated(
            itemId,
            tokenId,
            msg.sender,
            address(0),
            price,
            MarketItemStatus.Active
        );
    }

    function createMarketSale(uint256 itemId)
        external
        payable
        ItemExists(itemId)
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
        payable(idToMarketItem_.seller).transfer(msg.value);
        artD.transferFrom(address(this), msg.sender, tokenId);
        payable(owner()).transfer(listingPrice);
        idToMarketItem_.owner = payable(msg.sender);
        idToMarketItem_.status = MarketItemStatus.Sold;
        _itemsSold.increment();

        emit MarketItemSold(
            itemId,
            tokenId,
            idToMarketItem_.seller,
            msg.sender,
            idToMarketItem_.price,
            idToMarketItem_.status
        );
    }

    function cancelMarketItem(uint256 itemId)
        external
        ItemExists(itemId)
        nonReentrant
    {
        MarketItem storage idToMarketItem_ = idToMarketItem[itemId];
        require(msg.sender == idToMarketItem_.seller, "Only Seller can Cancel");
        require(
            idToMarketItem_.status == MarketItemStatus.Active,
            "Item must be active"
        );
        idToMarketItem_.status = MarketItemStatus.Cancelled;
        _itemsCancelled.increment();
        idToMarketItem_.seller.transfer(listingPrice);
        artD.transferFrom(address(this), msg.sender, idToMarketItem_.tokenId);

        emit MarketItemCreated(
            itemId,
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

    function fetchMyNFTs(address sender)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchItemsCreated(address sender)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }
}
