// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./structs/SaleParams.sol";
import "./structs/AuctionParams.sol";

// Abstract contract that serves as a provider for asset purchases
abstract contract AssetPurchaseProvider is ERC1155 {

    uint internal constant ERC20_TOKENID = type(uint256).max/2;

    mapping(uint => SaleParams) public assetsForSale; // Mapping to track assets available for sale
    mapping(uint => AuctionParams) public assetsInAuction; // Mapping to track assets in auction

    uint public marketplaceCutPromils; // Percentage cut taken by the marketplace from each transaction

    // Events
    event AssetOfferedForSale(uint indexed assetId, uint requestedPrice, uint durationInSeconds);
    event AssetHasBeenPurchased(uint indexed assetId, address indexed origOwner, address indexed newOwner);
    event AssetPlacedInAuction(uint indexed assetId, address indexed owner, uint minPrice, uint endDate);
    event BidPlacedForAssetInAuction(uint indexed assetId, address indexed bidder, uint newBiddingPrice);
    event AssetInAuctionHasBeenClosedWithNoBidders(uint indexed assetId);
    event AssetInAuctionHasBeenCompleted(uint indexed assetId, address indexed origAssetOwner, address indexed newAssetOwner, uint lastBiddingPrice);

    // Modifiers
    modifier onlyCurrentNftOwner(uint assetId_) {
        require(isCurrentNftOwner(msg.sender, assetId_), "not current asset owner/1");
        _;
    }

    modifier auctionHasEnded(uint assetId_) {
        require(_auctionHasEnded(assetId_), "auction has not ended");
        _;
    }

    modifier openForAll() {
        _;
    }

    // SALES

    /**
     * @dev Offer an asset for sale.
     * @param assetId_ The ID of the asset being offered for sale.
     * @param requestedPrice_ The requested price for the asset.
     * @param durationInSeconds_ The duration for which the asset will be available for sale.
     */
    function offerAssetForSale(uint assetId_, uint requestedPrice_, uint durationInSeconds_) onlyCurrentNftOwner(assetId_) external {
        require(!_auctionHasBidders(assetId_), "existing auction deposits");
        require(_isNftAsset(assetId_), "not an NFT asset");
        require(requestedPrice_ > 0, "no price was set");

        assetsForSale[assetId_] = SaleParams({
            origOwner: msg.sender,
            requestedPrice: requestedPrice_,
            endDate: block.timestamp + durationInSeconds_
        });

        emit AssetOfferedForSale(assetId_, requestedPrice_, durationInSeconds_);
    }

    /**
     * @dev Purchase an asset.
     * @param assetId_ The ID of the asset to purchase.
     */
    function purchaseAsset(uint assetId_) external payable openForAll {
        require(_isNftAsset(assetId_), "not an NFT asset");
        require(!_auctionHasBidders(assetId_), "existing auction deposits");

        address origOwner_ = assetsForSale[assetId_].origOwner;
        require(_assetOwnerNotChangedSinceOffer(assetId_, origOwner_), "asset now has a new owner");
        address assetOwner_ = origOwner_;

        require(_valueIsSufficientForSale(assetId_), "insufficient Eth value");
        require(_marketplaceIsApprovedByOwner(origOwner_), "marketplace not approved for asset");
        require(!_saleHasEnded(assetId_), "sale has ended");

        uint requestedPrice_ = assetsForSale[assetId_].requestedPrice;

        delete assetsForSale[assetId_];
        delete assetsInAuction[assetId_];

        _safeTransferFrom(assetOwner_, msg.sender, assetId_, 1, "");

        _transferEthFromMarketplace(requestedPrice_, assetOwner_);

        emit AssetHasBeenPurchased(assetId_, assetOwner_, msg.sender);
    }

    // AUCTIONS

    /**
     * @dev Place an asset in auction.
     * @param assetId_ The ID of the asset to place in auction.
     * @param requestedMinPrice_ The minimum price for the asset in the auction.
     * @param durationInSeconds_ The duration for which the asset will be in the auction.
     */
    function placeAssetInAuction(uint assetId_, uint requestedMinPrice_, uint durationInSeconds_) onlyCurrentNftOwner(assetId_) external {
        require(!_auctionHasBidders(assetId_), "existing auction deposits");
        require(_isNftAsset(assetId_), "not an NFT asset");
        require(requestedMinPrice_ > 0, "no price was set");

        uint endDate_ = block.timestamp + durationInSeconds_;

        assetsInAuction[assetId_] = AuctionParams({
            origOwner: msg.sender,
            lastBidder: address(0),
            minPrice: requestedMinPrice_,
            lastBiddingPrice: 0,
            endDate: endDate_
        });

        emit AssetPlacedInAuction(assetId_, msg.sender, requestedMinPrice_, endDate_);
    }

    /**
     * @dev Place a bid for an asset in auction.
     * @param assetId_ The ID of the asset in auction.
     */
    function placeBidForAssetInAuction(uint assetId_) external payable openForAll {
        uint newBiddingPrice_ = (msg.value * 1000) / (1000 + marketplaceCutPromils);

        uint priorBiddingPrice_ = assetsInAuction[assetId_].lastBiddingPrice;
        address priorBidder_ = assetsInAuction[assetId_].lastBidder;

        require(_hasActiveAuction(assetId_), "2/asset not placed in auction");
        require(_isNftAsset(assetId_), "not an NFT asset");
        require(_valueIsSufficientForAuction(assetId_), "insufficient eth value");
        require(!_auctionHasEnded(assetId_), "auction has ended");

        assetsInAuction[assetId_].lastBidder = msg.sender;
        assetsInAuction[assetId_].lastBiddingPrice = newBiddingPrice_;

        delete assetsForSale[assetId_];

        if (priorBidder_ != address(0)) {
            _transferEthFromMarketplace(priorBiddingPrice_, priorBidder_);
        }

        emit BidPlacedForAssetInAuction(assetId_, msg.sender, newBiddingPrice_);
    }

    /**
     * @dev Complete an auction for an asset.
     * @param assetId_ The ID of the asset in auction.
     */
    function completeAuction(uint assetId_) external openForAll auctionHasEnded(assetId_) {
        if (!_auctionHasBidders(assetId_)) {
            delete assetsInAuction[assetId_];
            emit AssetInAuctionHasBeenClosedWithNoBidders(assetId_);
            return;
        }
        address lastBidder_ = assetsInAuction[assetId_].lastBidder;
        uint lastBiddingPrice_ = assetsInAuction[assetId_].lastBiddingPrice;
        address assetOwner_ = assetsInAuction[assetId_].origOwner;

        require(isCurrentNftOwner(assetOwner_, assetId_), "not current asset owner/2");

        delete assetsInAuction[assetId_];
        delete assetsForSale[assetId_];

        safeTransferFrom(assetOwner_, lastBidder_, assetId_, 1, "");

        _transferEthFromMarketplace(lastBiddingPrice_, assetOwner_);

        emit AssetInAuctionHasBeenCompleted(assetId_, assetOwner_, lastBidder_, lastBiddingPrice_);
    }

    // INTERNAL FUNCTIONS

    /**
     * @dev Check if the current address is the owner of the asset.
     * @param addr_ The address to check.
     * @param assetId_ The ID of the asset.
     * @return A boolean indicating whether the address is the owner of the asset.
     */
    function isCurrentNftOwner(address addr_, uint assetId_) virtual public view returns (bool);

    /**
     * @dev Check if the value is sufficient for placing a bid in the auction.
     * @param assetId_ The ID of the asset in auction.
     * @return A boolean indicating whether the value is sufficient.
     */
    function _valueIsSufficientForAuction(uint assetId_) private view returns (bool) {
        uint minPrice_ = assetsInAuction[assetId_].minPrice;
        uint lastBiddingPrice_ = assetsInAuction[assetId_].lastBiddingPrice;

        uint newBiddingPrice_ = (lastBiddingPrice_ > 0) ? lastBiddingPrice_ + 1 : minPrice_;

        return msg.value >= (newBiddingPrice_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    /**
     * @dev Check if an asset has bidders in the auction.
     * @param assetId_ The ID of the asset in auction.
     * @return A boolean indicating whether the asset has bidders.
     */
    function _auctionHasBidders(uint assetId_) private view returns (bool) {
        return assetsInAuction[assetId_].lastBidder != address(0);
    }

    /**
     * @dev Check if the asset is an NFT asset.
     * @param assetId_ The ID of the asset.
     * @return A boolean indicating whether the asset is an NFT asset.
     */
    function _isNftAsset(uint assetId_) private pure returns (bool) {
        return assetId_ < ERC20_TOKENID;
    }

    /**
     * @dev Check if the asset owner has not changed since the offer.
     * @param assetId_ The ID of the asset.
     * @param origOwner_ The original owner of the asset.
     * @return A boolean indicating whether the asset owner has not changed.
     */
    function _assetOwnerNotChangedSinceOffer(uint assetId_, address origOwner_) private view returns (bool) {
        return isCurrentNftOwner(origOwner_, assetId_);
    }

    /**
     * @dev Check if the value is sufficient for purchasing the asset.
     * @param assetId_ The ID of the asset.
     * @return A boolean indicating whether the value is sufficient.
     */
    function _valueIsSufficientForSale(uint assetId_) private view returns (bool) {
        uint price_ = assetsForSale[assetId_].requestedPrice;
        require(price_ > 0, "asset is not for sale");
        return msg.value >= (price_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    /**
     * @dev Check if the marketplace is approved by the owner of the asset.
     * @param owner_ The owner of the asset.
     * @return A boolean indicating whether the marketplace is approved.
     */
    function _marketplaceIsApprovedByOwner(address owner_) private view returns (bool) {
        return isApprovedForAll(owner_, address(this));
    }

    /**
     * @dev Check if the sale has ended.
     * @param assetId_ The ID of the asset.
     * @return A boolean indicating whether the sale has ended.
     */
    function _saleHasEnded(uint assetId_) private view returns (bool) {
        uint endDate_ = assetsForSale[assetId_].endDate;
        return block.timestamp > endDate_;
    }

    /**
     * @dev Check if the auction has ended.
     * @param assetId_ The ID of the asset in auction.
     * @return A boolean indicating whether the auction has ended.
     */
    function _auctionHasEnded(uint assetId_) private view returns (bool) {
        uint endDate_ = assetsInAuction[assetId_].endDate;
        return block.timestamp > endDate_;
    }

    /**
     * @dev Check if the auction is active for the asset.
     * @param assetId_ The ID of the asset in auction.
     * @return A boolean indicating whether the auction is active.
     */
    function _hasActiveAuction(uint assetId_) private view returns (bool) {
        return assetsInAuction[assetId_].endDate != 0;
    }

    /**
     * @dev Transfer ETH from the marketplace to a recipient.
     * @param amount_ The amount of ETH to transfer.
     * @param recipient_ The recipient of the ETH.
     */
    function _transferEthFromMarketplace(uint amount_, address recipient_) private {
        (bool ok,) = payable(recipient_).call{ value: amount_ }("");
        require(ok, "ether transfer failed");
    }
}
