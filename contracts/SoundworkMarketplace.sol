// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SoundworkMarketplace is ERC1155, Ownable {

    uint public constant ERC20_TOKENID = type(uint256).max/2;

    uint public immutable erc20Supply;


    uint public nextTokenId;

    uint public marketplaceCutPromils;


    mapping(uint => SoundAsset) public soundAssets;

    mapping(uint => PackAsset) public packAssets;



    mapping(uint => SaleParams) public assetsForSale;

    mapping(uint => AuctionParams) public assetsInAuction;

    //----------


    event MarketplaceCutChanged(uint oldVal, uint newVal);

    event SoundAssetCreated(uint indexed assetId, address indexed assetOwner);

    event PackAssetCreated(uint indexed assetId, address indexed assetOwner);

    event AssetOfferedForSale( uint indexed assetId, uint requstedPrice, uint durationInSeconds);

    event AssetHasBeenPurchased( uint indexed assetId, address indexed origOwner, address indexed newOwner);

    event AssetPlacedInAuction( uint indexed assetId, address indexed owner, uint minPrice, uint endDate);

    event BidPlacedForAssetInAuction( uint indexed assetId, address indexed bidder, uint newBiddingPrice);

    event AssetInAuctionHasBeenCompleted( uint indexed assetId, address indexed origAssetOwner, address indexed newAssetOwner, uint lastBiddingPrice);

    event AssetInAuctionHasBeenClosedWithNoBidders( uint indexed assetId);

    //---------



    enum AssetType {
        Sound,
        Pack,
        Element,
        Track
    }


    struct SoundAsset {
        //●	Name: The title of the music piece, sound, sample, or loop.
        string name;
        //●	Format: The file format of the music asset (e.g., WAV, MP3, MIDI).
        string format;
        //●	Media Files: The actual music files or links to the hosted files.
        string mediaFiles;
        //●	Tempo: The beats per minute (BPM) of the music piece, if applicable.
        uint256 tempo;
        //●	Genre: The musical genre or style of the asset.
        string genre;
        //●	Style: A more specific description of the style, if applicable.
        string style;
        //●	Base Note: The root note or key of the music piece, if applicable.
        string baseNote;
        //●	Signature: The time signature of the music piece, if applicable.
        string signature;
        //●	Author Address: The blockchain address of the creator.
        address authorAddress;


        /* zzzz: comment out to solve CompilerError: Stack too deep. Try compiling with `--via-ir` (cli) 
        
        //●	Description: A brief description of the music asset.
        string description;
        //●	Author Name: The creator's name or pseudonym.
        string authorName;
        //●	Collaborators: An array of blockchain addresses representing collaborators, if any, and the percentage of the Revenue each collaborator should receive.
        address[] collaborators;
        //●	Units available: The number of available units/copies for sale or distribution.
        uint256 unitsAvailable;
        //●	Maximum Supply: The maximum possible supply of the NFT, if there's a limit.
        uint256 totalPossibleSupply;
        //●	Date Created: The creation date of the music asset.
        uint256 dateCreated;
        //●	License: An NFT address representing the license type and its terms for the music asset.
        address licenseNFTAddress;
        //●	License type:
        string licenseType;
        */
    }


    struct PackAsset {
        //●	Name: The title of the music piece, sound, sample, or loop.
        string name;
        //●	Sounds: a Collection / Array of SOUND NFTs
        uint[] soundAssetIds;
        //●	Elements: a Collection / Array of ELEMENT NFTs
        uint[] elementAssetIds;
        //●	Genre: The musical genre or style of the asset.
        string genre;
        //●	Description: A brief description of the music asset.
        string description;
        //●	Author Address: The blockchain address of the creator.
        address authorAddress;
        //●	Author Name: The creator's name or pseudonym.
        string authorName;
        //●	Collaborators: An array of blockchain addresses representing collaborators, if any, and the percentage of the Revenue each collaborator should receive.
        address[] collaborators;
        //●	Units available: The number of available units/copies for sale or distribution.
        uint256 unitsAvailable;
        //●	Maximum Supply: The maximum possible supply of the NFT, if there's a limit.
        uint256 totalPossibleSupply;
        //●	Date Created: The creation date of the music asset.
        uint256 dateCreated;
        //●	License: An NFT address representing the license type and its terms for the music asset.
        address licenseNFTAddress;
        //●	License type:
        string licenseType;
    }


    struct SaleParams {
        address origOwner;
        uint requestedPrice;
        uint endDate;
    }

    struct AuctionParams {
        address origOwner;
        address lastBidder;
        uint minPrice;
        uint lastBiddingPrice;
        uint endDate;
    }

    //--------


    modifier openForAll() {
        _;
    }

    modifier auctionHasEnded(uint assetId_) {
        require( _auctionHasEnded( assetId_));
        _;
    }

    modifier isCurrentNftOwner(uint assetId_) {
        require( _isCurrentNftOwner( msg.sender, assetId_), "not current asset owner");
        _;
    }

    //--------


    constructor( uint marketplaceCutPromils_, uint erc20Supply_, string memory uri_) ERC1155(uri_) {
        // set marketplace cut
        marketplaceCutPromils = marketplaceCutPromils_;

        erc20Supply = erc20Supply_;

        // and mint erc20 marketplace tokens
        _mint( address(this), ERC20_TOKENID, erc20Supply_, "");
    }

    function setMarketplaceCutPromils(uint marketplaceCutPromils_) external onlyOwner { //@PUBFUNC
        uint oldVal = marketplaceCutPromils;
        marketplaceCutPromils = marketplaceCutPromils_;
        emit MarketplaceCutChanged(oldVal, marketplaceCutPromils);
    }

    function transferErc20MarketplaceTokens( address to_, uint numTokens_) external onlyOwner { //@PUBFUNC
        _safeTransferFrom( address(this), to_, ERC20_TOKENID, numTokens_, "");
    }
    //---------


    function createSoundAsset( SoundAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint id_ = _mintAssetNft( assetOwner_);

        soundAssets[ id_] = asset;

        emit SoundAssetCreated(id_, assetOwner_);
    }


    function createPackAsset( PackAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint id_ = _mintAssetNft( assetOwner_);

        packAssets[ id_] = asset;

        emit PackAssetCreated(id_, assetOwner_);
    }


    // ----------------------  Asset purchase -----------------------

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
        require( !_saleHasEnded(assetId_), "sale had ended");

        uint requestedPrice_ = assetsForSale[ assetId_].requestedPrice;

        delete assetsForSale[ assetId_];
        delete assetsInAuction[ assetId_]; // also delete any pending actions (but not with deposits)

        // transfer asset to msg.sender;
        _safeTransferFrom( assetOwner_, msg.sender, assetId_, 1, "");

        // and pass payment to asset owner
        _transferEthFromMarketplace( requestedPrice_, assetOwner_);

        emit AssetHasBeenPurchased( assetId_, assetOwner_, msg.sender);
    }



    // ----------------------  Asset auction -----------------------

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

        require( _isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner");

        delete assetsInAuction[ assetId_];

        // transfer asset to last bidder;
        _safeTransferFrom( assetOwner_, lastBidder_, assetId_, 1, "");

        // and pass ether payment to current asset owner
        _transferEthFromMarketplace( lastBiddingPrice_, assetOwner_);

        emit AssetInAuctionHasBeenCompleted( assetId_, assetOwner_, lastBidder_, lastBiddingPrice_);
    }

    // ---------------



    function _verifyNotNull( address addr_) private pure returns(address) {
        require( addr_ != address(0), "no address was provided");
        return addr_;
    }

    function _mintAssetNft( address assetOwner_) private returns(uint) {
        uint id_ = ++nextTokenId;
        _mint( assetOwner_, id_, 1, "");
        return id_;
    }

    function _valueIsSufficientForAuction( uint assetId_) private view returns(bool) {
        uint minPrice_ = assetsInAuction[ assetId_].minPrice;
        uint lastBiddingPrice_ = assetsInAuction[ assetId_].lastBiddingPrice;

        uint newBiddingPrice_ = (lastBiddingPrice_ > 0) ? lastBiddingPrice_ + 1 : minPrice_;

        return msg.value >= (newBiddingPrice_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    function _hasActiveAuction( uint assetId_) private view returns(bool) {
        return assetsInAuction[ assetId_].minPrice > 0 &&
                block.timestamp <= assetsInAuction[ assetId_].endDate;
    }

    function _auctionHasEnded( uint assetId_) private view returns(bool) {
        uint endDate_ = assetsInAuction[ assetId_].endDate;
        require( endDate_ > 0, "no auction was detected");
        return block.timestamp >= endDate_;
    }


    function _isNftAsset(uint assetId_) private pure returns(bool) {
        return assetId_ < ERC20_TOKENID;
    }

    function _transferEthFromMarketplace( uint value_, address to_) private {
        (bool ok,) = to_.call{ value: value_ }("");
        require( ok, "failed to transfer Ether");
    }

    function _valueIsSufficientForSale(uint assetId_) private view returns(bool) {
        uint price_ = assetsForSale[ assetId_].requestedPrice;
        require( price_ > 0, "asset is not for sale");
        return msg.value >= (price_ * (1000 + marketplaceCutPromils)) / 1000;
    }

    function _auctionHasBidders(uint assetId_) private view returns(bool) {
        return assetsInAuction[ assetId_].lastBidder != address(0);
    }

    function _assetOwnerNotChangedSinceOffer( uint assetId_, address origOwner_) private view returns(bool) {
        return _isCurrentNftOwner( origOwner_, assetId_);
    }

    function _marketplaceIsApprovedByOwner(address owner_) private view returns(bool) {
        return isApprovedForAll(owner_, address(this));
    }

    function _saleHasEnded(uint assetId_) private view returns(bool) {
        return block.timestamp <= assetsForSale[ assetId_].endDate;
    }

    function _isCurrentNftOwner( address addr_, uint assetId_) private view returns(bool) {
        uint numNfts = balanceOf( addr_, assetId_);
        require( numNfts <= 1, "nft must be unique.");
        return numNfts == 1;
    }

}