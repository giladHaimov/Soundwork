// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./AssetPurchaseProvider.sol";
import "./structs/SoundAsset.sol";
import "./structs/PackAsset.sol";
import "./structs/ElementAsset.sol";
import "./structs/TrackAsset.sol";
import "./structs/AssetType.sol";


abstract contract AssetMinter is AssetPurchaseProvider, Ownable {

    uint public nextTokenId;


    mapping(uint => SoundAsset) public soundAssets;

    mapping(uint => PackAsset) public packAssets;

    mapping(uint => ElementAsset) public elementAssets;

    mapping(uint => TrackAsset) public trackAssets;


    event SoundAssetCreated(uint indexed assetId, address indexed assetOwner);

    event ElementAssetCreated(uint indexed assetId, address indexed assetOwner);

    event TrackAssetCreated(uint indexed assetId, address indexed assetOwner);

    event PackAssetCreated(uint indexed assetId, address indexed assetOwner);

    event NewAssetCreated(uint indexed assetId, AssetType indexed assetType, address indexed assetOwner);
    //------


    function createSoundAsset( SoundAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint assetId_ = _mintAssetNft( assetOwner_, AssetType.Sound);

        soundAssets[ assetId_] = asset;

        require( isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner/4");

        emit SoundAssetCreated(assetId_, assetOwner_);
    }

    function createElementAsset( ElementAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint assetId_ = _mintAssetNft( assetOwner_, AssetType.Element);

        elementAssets[ assetId_] = asset;

        require( isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner/6");

        emit ElementAssetCreated(assetId_, assetOwner_);
    }

    function createTrackAsset( TrackAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint assetId_ = _mintAssetNft( assetOwner_, AssetType.Track);

        trackAssets[ assetId_] = asset;

        require( isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner/7");

        emit TrackAssetCreated(assetId_, assetOwner_);
    }

    function createPackAsset( PackAsset memory asset) external onlyOwner {
        address assetOwner_ = _verifyNotNull( asset.authorAddress);

        uint id_ = _mintAssetNft( assetOwner_, AssetType.Pack);

        packAssets[ id_] = asset;

        emit PackAssetCreated(id_, assetOwner_);
    }
    //--------

    function _mintAssetNft( address assetOwner_, AssetType type_) private returns(uint) {
        uint assetId_ = ++nextTokenId;
        _mint( assetOwner_, assetId_, 1, "");

        require( isCurrentNftOwner( assetOwner_, assetId_), "not current asset owner/3");

        emit NewAssetCreated(assetId_, type_, assetOwner_);

        return assetId_;
    }

    function _verifyNotNull( address addr_) private pure returns(address) {
        require( addr_ != address(0), "no address was provided");
        return addr_;
    }

    function  isCurrentNftOwner( address addr_, uint assetId_) public override view returns(bool) {
        uint numNfts = balanceOf( addr_, assetId_);
        require( numNfts <= 1, "nft must be unique.");
        return numNfts == 1;
    }

}