// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

interface IERC1155 {
    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

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
        uint256 quantity;
        address seller;
        uint256 price;
        MarketItemStatus status;
    }
    mapping(uint256 => mapping(address => uint256)) owners;
    mapping(uint256 => MarketItem) private idToMarketItem;

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    event ListingCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 quantity,
        address seller,
        uint256 price
    );

    event ListingCancelled(uint256 indexed itemId, uint256 quantity);

    event ListingBuy(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 quantity,
        address seller,
        address buyer
    );
    event RoyaltyPaid(address indexed receiver, uint256 indexed amount);

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 quantity_,
        uint256 price
    ) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        require(quantity_ > 0, "quantity must be greater than 0");
        require(
            IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= quantity_,
            "seller does not own listed quantity of tokens"
        );

        _itemIds.increment();

        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            quantity_,
            payable(msg.sender),
            price,
            MarketItemStatus.Active
        );
        emit ListingCreated(
            itemId,
            nftContract,
            tokenId,
            quantity_,
            msg.sender,
            price
        );
    }

    function Buy(
        address nftContract,
        uint256 itemId,
        uint256 quantity_
    ) external payable nonReentrant {
        MarketItem storage idToMarketItem_ = idToMarketItem[itemId];
        uint256 tokenId = idToMarketItem_.tokenId;
        require(quantity_ > 0, "Amount must not be zero");
        require(
            quantity_ <= idToMarketItem_.quantity,
            "Amount must less then item on sell"
        );
        require(
            idToMarketItem_.status == MarketItemStatus.Active,
            "Listing Not Active"
        );

        require(msg.sender != idToMarketItem_.seller, "Seller can't be buyer");
        uint256 totalPrice = idToMarketItem_.price * quantity_;
        require(
            msg.value == totalPrice,
            "Please submit the asking price in order to complete the purchase"
        );

        (address royaltyReceiver, uint256 royaltyAmount) = getRoyalties(
            idToMarketItem_.nftContract,
            idToMarketItem_.tokenId,
            totalPrice
        );

        require(royaltyAmount <= totalPrice, "royalty amount too big");

        if (royaltyAmount > 0) {
            payable(royaltyReceiver).transfer(royaltyAmount);
            emit RoyaltyPaid(royaltyReceiver, royaltyAmount);
        }

        payable(idToMarketItem_.seller).transfer(msg.value - royaltyAmount);

        IERC1155(nftContract).safeTransferFrom(
            idToMarketItem_.seller,
            msg.sender,
            tokenId,
            quantity_,
            ""
        );
        owners[itemId][msg.sender] = quantity_;
        idToMarketItem_.quantity = idToMarketItem_.quantity - quantity_;
        if (idToMarketItem_.quantity == 0) {
            idToMarketItem_.status = MarketItemStatus.Sold;
            _itemsSold.increment();
            payable(owner).transfer(listingPrice);
        }
        emit ListingBuy(
            itemId,
            nftContract,
            tokenId,
            quantity_,
            idToMarketItem_.seller,
            msg.sender
        );
    }

    function getRoyalties(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) private view returns (address receiver, uint256 royaltyAmount) {
        (receiver, royaltyAmount) = IERC1155(nftContract).royaltyInfo(
            tokenId,
            price
        );
        if (receiver == address(0) || royaltyAmount == 0) {
            return (address(0), 0);
        }
        return (receiver, royaltyAmount);
    }

    uint256 maxRoyaltiesBasisPoints = 4000;

    function cancelMarketItem(uint256 itemId, uint256 quantity_)
        external
        nonReentrant
    {
        MarketItem storage idToMarketItem_ = idToMarketItem[itemId];
        require(msg.sender == idToMarketItem_.seller, "Only Seller can Cancel");
        require(
            idToMarketItem_.status == MarketItemStatus.Active,
            "Item must be active"
        );
        require(quantity_ > 0, "quantity must more than 0 ");
        require(idToMarketItem_.quantity >= quantity_, "Item must be more ");
        idToMarketItem_.quantity = idToMarketItem_.quantity - quantity_;
        if (idToMarketItem_.quantity == 0) {
            _itemsCancelled.increment();
            idToMarketItem_.status = MarketItemStatus.Cancelled;
            payable(idToMarketItem_.seller).transfer(listingPrice);
        }

        emit ListingCancelled(itemId, quantity_);
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
        returns (MarketItem[] memory, uint256[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (owners[i + 1][sender] != 0) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256[] memory quantity = new uint256[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (owners[i + 1][sender] != 0) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                quantity[currentIndex] = owners[currentId][sender];
                currentIndex += 1;
            }
        }
        return (items, quantity);
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
}
