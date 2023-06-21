// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./AssetMinter.sol";

contract SoundworkMarketplace is /*ERC1155*/ AssetMinter {
    // Immutable variable to store the ERC20 token supply

    uint constant public MAX_MARKETPLACE_CUT_PROMILS = 40; // == 4%

    uint public immutable erc20Supply;

    // Event emitted when the marketplace cut is changed
    event MarketplaceCutChanged(uint oldVal, uint newVal);

    // Constructor function
    constructor(uint marketplaceCutPromils_, uint erc20Supply_, string memory uri_) ERC1155(uri_) {
        // Set the marketplace cut
        marketplaceCutPromils = marketplaceCutPromils_;

        // Set the ERC20 token supply
        erc20Supply = erc20Supply_;

        // Mint ERC20 marketplace tokens and assign them to the contract address
        _mint(address(this), ERC20_TOKENID, erc20Supply_, "");
    }

    // Function to set the marketplace cut percentage
    function setMarketplaceCutPromils(uint marketplaceCutPromils_) external onlyOwner { //@PUBFUNC
        require( marketplaceCutPromils_ <= MAX_MARKETPLACE_CUT_PROMILS, "cut exceeds max");
        // Store the old value of marketplaceCutPromils
        uint oldVal = marketplaceCutPromils;

        // Update the marketplace cut percentage
        marketplaceCutPromils = marketplaceCutPromils_;

        // Emit an event to notify listeners about the change in marketplace cut
        emit MarketplaceCutChanged(oldVal, marketplaceCutPromils);
    }

    // Function to transfer ERC20 marketplace tokens to a specified address
    function transferErc20MarketplaceTokens(address to_, uint numTokens_) external onlyOwner { //@PUBFUNC
        // Safely transfer ERC20 marketplace tokens from the contract address to the specified address
        safeTransferFrom(address(this), to_, ERC20_TOKENID, numTokens_, "");
    }
}
