// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

struct PackAsset {
    //	Name: The title of the music piece, sound, sample, or loop.
    string name;
    //	Sounds: a Collection / Array of SOUND NFTs
    uint[] soundAssetIds;
    //	Elements: a Collection / Array of ELEMENT NFTs
    uint[] elementAssetIds;
    //	Genre: The musical genre or style of the asset.
    string genre;
    //	Description: A brief description of the music asset.
    string description;
    //	Author Address: The blockchain address of the creator.
    address authorAddress;
    //	Author Name: The creator's name or pseudonym.
    string authorName;
    //	Collaborators: An array of blockchain addresses representing collaborators, if any, and the percentage of the Revenue each collaborator should receive.
    address[] collaborators;
    //	Units available: The number of available units/copies for sale or distribution.
    uint256 unitsAvailable;
    //	Maximum Supply: The maximum possible supply of the NFT, if there's a limit.
    uint256 totalPossibleSupply;
    //	Date Created: The creation date of the music asset.
    uint256 dateCreated;
    //	License: An NFT address representing the license type and its terms for the music asset.
    address licenseNFTAddress;
    //	License type:
    string licenseType;
}

