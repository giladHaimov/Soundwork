// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

struct ElementAsset {
    // Name: The title of the music piece, sound, sample, or loop.
    string name;
    // Type: { MIDI | VST |  PRESET | TEMPLATE | OTHER}
    string assetType;
    // Media Files: The actual element files or links to the hosted files.
    string mediaFiles;
    // Description: A brief description of the music asset.
    string description;
    // Author Name: The creator's name or pseudonym.
    string authorName;
    // Author Address: The blockchain address of the creator.
    address authorAddress;
    // Collaborators: An array of blockchain addresses representing collaborators, if any, and the percentage of the Revenue each collaborator should receive.
    address[] collaborators;
    // Units available: The number of available units/copies for sale or distribution.
    uint256 unitsAvailable;
    // Maximum Supply: The maximum possible supply of the NFT, if there's a limit.
    uint256 totalPossibleSupply;
    // Date Created: The creation date of the music asset.
    uint256 dateCreated;
    // License: An NFT address representing the license type and its terms for the sample pack.
    address licenseNFTAddress;
}
