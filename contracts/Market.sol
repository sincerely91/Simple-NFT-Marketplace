//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./IERC721.sol";
import "hardhat/console.sol";

contract Market {
    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Listing {
        ListingStatus status;
        address seller;
        address token;
        uint256 tokenId;
        uint256 price;
    }
    event Listed(
        uint256 listingId,
        address seller,
        address token,
        uint256 tokenId,
        uint256 price
    );

    event Sale(
        uint256 listingId,
        address buyer,
        address token,
        uint256 tokenId,
        uint256 price
    );
    event Cancel(uint256 listingId, address seller);

    uint256 private _listingId;

    mapping(uint256 => Listing) private _listings;

    function listingToken(
        address token,
        uint256 tokenId,
        uint256 price
    ) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        Listing memory listing = Listing(
            ListingStatus.Active,
            msg.sender,
            token,
            tokenId,
            price
        );
        _listingId++;
        _listings[_listingId] = listing;
        emit Listed(_listingId, msg.sender, token, tokenId, price);
    }

    function getListing(uint256 listingId)
        public
        view
        returns (Listing memory)
    {
        return _listings[listingId];
    }

    function buyToken(uint256 listingId) external payable {
        Listing storage listing = _listings[listingId];
        require(listing.status == ListingStatus.Active, "Listing Not Active");
        require(msg.sender != listing.seller, "Seller can't be buyer");
        require(msg.value >= listing.price, "Price is too less");
        listing.status = ListingStatus.Sold;
        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
        payable(listing.seller).transfer(listing.price);

        emit Sale(
            listingId,
            msg.sender,
            listing.token,
            listing.tokenId,
            listing.price
        );
    }

    function cancel(uint256 listingId) public {
        Listing storage listing = _listings[listingId];
        require(msg.sender == listing.seller, "Only Seller can Cancel");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not Active"
        );
        listing.status == ListingStatus.Cancelled;
        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
        emit Cancel(listingId, listing.seller);
    }
}
