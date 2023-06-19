// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

struct SoundAsset {
    //	Name: The title of the music piece, sound, sample, or loop.
    string name;
    //	Format: The file format of the music asset (e.g., WAV, MP3, MIDI).
    string format;
    //	Media Files: The actual music files or links to the hosted files.
    string mediaFiles;
    //	Tempo: The beats per minute (BPM) of the music piece, if applicable.
    uint256 tempo;
    //	Genre: The musical genre or style of the asset.
    string genre;
    //	Style: A more specific description of the style, if applicable.
    string style;
    //	Base Note: The root note or key of the music piece, if applicable.
    string baseNote;
    //	Signature: The time signature of the music piece, if applicable.
    string signature;
    //	Author Address: The blockchain address of the creator.
    address authorAddress;


    /* zzzz: comment out to solve CompilerError: Stack too deep. Try compiling with `--via-ir` (cli)

    //	Description: A brief description of the music asset.
    string description;
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
    */
}

