// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./structs/SaleParams.sol";
import "./structs/AuctionParams.sol";
import "./AssetPurchaseProvider.sol";


abstract contract AssetPurchaseProvider is ERC1155 {

    uint public constant ERC20_TOKENID = type(uint256).max/2;

    mapping(uint => SaleParams) public assetsForSale;

    mapping(uint => AuctionParams) public assetsInAuction;

    uint public marketplaceCutPromils;

    //---------
    event AssetOfferedForSale( uint indexed assetId, uint requstedPrice, uint durationInSeconds);

    event AssetHasBeenPurchased( uint indexed assetId, address indexed origOwner, address indexed newOwner);

    event AssetPlacedInAuction( uint indexed assetId, address indexed owner, uint minPrice, uint endDate);

    event BidPlacedForAssetInAuction( uint indexed assetId, address indexed bidder, uint newBiddingPrice);

    event AssetInAuctionHasBeenClosedWithNoBidders( uint indexed assetId);

    event AssetInAuctionHasBeenCompleted( uint indexed assetId, address indexed origAssetOwner, address indexed newAssetOwner, uint lastBiddingPrice);


    //-------
    modifier isCurrentNftOwner(uint assetId_) {
        require( _isCurrentNftOwner( msg.sender, assetId_), "not current asset owner/1");
        _;
    }

    modifier auctionHasEnded(uint assetId_) {
        require( _auctionHasEnded( assetId_));
        _;
    }

    modifier openForAll() {
        _;
    }


    //============  SALES  ==================

    function offerAssetForSale(uint assetId_, uint requstedPrice_,
        uint durationInSeconds_) isCurrentNftOwner(assetId_) external {
        // asset may have prior assetsForSale or assetsInAuction records, but NOT an auction in-progress i.e. with existing deposits
        require( !_auctionHasBidders(assetId_), "existing auction deposits");
        require( _isNftAsset(assetId_), "not an NFT asset");
        require( requstedPrice_ > 0, "no price was set");

        assetsForSale[ assetId_] =  SaleParams({
            origOwner: msg.sender,
            requestedPrice: requstedPrice_,
            endDate: block.timestamp + durationInSeconds_});

        emit AssetOfferedForSale( assetId_, requstedPrice_, durationInSeconds_);
    }

    function purchaseAsset(uint assetId_) external payable openForAll {
        require( _isNftAsset(assetId_), "not an NFT asset");
        require( !_auctionHasBidders(assetId_), "existing auction deposits");

        address origOwner_ = assetsForSale[ assetId_].origOwner;
        require( _assetOwnerNotChangedSinceOffer(assetId_, origOwner_), "asset now has a new owner");
        address assetOwner_ = origOwner_;

        require( _valueIsSufficientForSale(assetId_), "insufficient Eth value");
        require( _marketplaceIsApprovedByOwner(origOwner_), "marketplace not approved for asset");
        require( !_saleHasEnded(assetId_), "sale has ended");

        uint requestedPrice_ = assetsForSale[ assetId_].requestedPrice;

        delete assetsForSale[ assetId_];
        delete assetsInAuction[ assetId_]; // also delete any pending actions (but not with deposits)

        // transfer asset to msg.sender;
        _safeTransferFrom( assetOwner_, msg.sender, assetId_, 1, "");

        // and pass payment to asset owner
        _transferEthFromMarketplace( requestedPrice_, assetOwner_);

        emit AssetHasBeenPurchased( assetId_, assetOwner_, msg.sender);
    }


    //============  AUCTIONS ==================

    function placeAssetInAuction(uint assetId_, uint requstedMinPrice_, uint durationInSeconds_)
        isCurrentNftOwner(assetId_) external {
        // asset may have prior assetsForSale or assetsInAuction records, but NOT an auction in-progress i.e. with existing deposits
        require( !_auctionHasBidders(assetId_), "existing auction deposits");
        require( _isNftAsset(assetId_), "not an NFT asset");
        require( requstedMinPrice_ > 0, "no price was set");

        uint endDate_ = block.timestamp + durationInSeconds_;

        assetsInAuction[ assetId_] =  AuctionParams({
        origOwner: msg.sender,
        lastBidder: address(0),
        minPrice: requstedMinPrice_,
        lastBiddingPrice: 0,
        endDate: endDate_});

        emit AssetPlacedInAuction( assetId_, msg.sender, requstedMinPrice_, endDate_);
    }


    function placeBidForAssetInAuction(uint assetId_) external payable openForAll {

        // msg.value == (newBiddingPrice * (1000 + marketplaceCutPromils)) / 1000
        uint newBiddingPrice_ = (msg.value * 1000) / (1000 + marketplaceCutPromils);

        uint priorBiddingPrice_ = assetsInAuction[ assetId_].lastBiddingPrice;
        address priorBidder_ = assetsInAuction[ assetId_].lastBidder;

        require( _isNftAsset(assetId_), "not an NFT asset");
        require( _hasActiveAuction(assetId_), "has an existing auction with deposits");
        require( _valueIsSufficientForAuction(assetId_), "insufficient eth value");
        require( !_auctionHasEnded(assetId_), "auction has ended");

        assetsInAuction[ assetId_].lastBidder = msg.sender;
        assetsInAuction[ assetId_].lastBiddingPrice = newBiddingPrice_;

        if (priorBidder_ != address(0)) {
            _transferEthFromMarketplace( priorBiddingPrice_, priorBidder_);
        }

        emit BidPlacedForAssetInAuction( assetId_, msg.sender, newBiddingPrice_);
    }


    function completeAuction(uint assetId_) external openForAll auctionHasEnded(assetId_) {
        if ( !_auctionHasBidders( assetId_)) {
            delete assetsInAuction[ assetId_];
            emit AssetInAuctionHasBeenClosedWithNoBidders( assetId_);
            return;
        }
        address lastBidder_ = assetsInAuction[ assetId_].lastBidder;
        uint lastBiddingPrice_ = assetsInAuction[ assetId_].lastBiddingPrice;
        address assetOwner_ = assetsInAuction[ assetId_].origOwner;

        require( _isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner/2");

        delete assetsInAuction[ assetId_];

        // transfer asset to last bidder;
        _safeTransferFrom( assetOwner_, lastBidder_, assetId_, 1, "");

        // and pass ether payment to current asset owner
        _transferEthFromMarketplace( lastBiddingPrice_, assetOwner_);

        emit AssetInAuctionHasBeenCompleted( assetId_, assetOwner_, lastBidder_, lastBiddingPrice_);
    }


    //===============================


    function _isCurrentNftOwner( address addr_, uint assetId_) virtual internal view returns(bool);

    function _valueIsSufficientForAuction( uint assetId_) private view returns(bool) {
        uint minPrice_ = assetsInAuction[ assetId_].minPrice;
        uint lastBiddingPrice_ = assetsInAuction[ assetId_].lastBiddingPrice;

        uint newBiddingPrice_ = (lastBiddingPrice_ > 0) ? lastBiddingPrice_ + 1 : minPrice_;

        return msg.value >= (newBiddingPrice_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    function _auctionHasBidders(uint assetId_) private view returns(bool) {
        return assetsInAuction[ assetId_].lastBidder != address(0);
    }

    function _isNftAsset(uint assetId_) private pure returns(bool) {
        return assetId_ < ERC20_TOKENID;
    }

    function _assetOwnerNotChangedSinceOffer( uint assetId_, address origOwner_) private view returns(bool) {
        return _isCurrentNftOwner( origOwner_, assetId_);
    }

    function _valueIsSufficientForSale(uint assetId_) private view returns(bool) {
        uint price_ = assetsForSale[ assetId_].requestedPrice;
        require( price_ > 0, "asset is not for sale");
        return msg.value >= (price_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    function _marketplaceIsApprovedByOwner(address owner_) private view returns(bool) {
        return isApprovedForAll(owner_, address(this));
    }

    function _saleHasEnded(uint assetId_) private view returns(bool) {
        return block.timestamp > assetsForSale[ assetId_].endDate;
    }

    function _transferEthFromMarketplace( uint value_, address to_) private {
        (bool ok,) = to_.call{ value: value_ }("");
        require( ok, "failed to transfer Ether");
    }

    function _auctionHasEnded( uint assetId_) private view returns(bool) {
        uint endDate_ = assetsInAuction[ assetId_].endDate;
        require( endDate_ > 0, "no auction was detected");
        return block.timestamp >= endDate_;
    }

    function _hasActiveAuction( uint assetId_) private view returns(bool) {
        return assetsInAuction[ assetId_].minPrice > 0 &&
        block.timestamp <= assetsInAuction[ assetId_].endDate;
    }

}
