// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./AssetMinter.sol";


contract SoundworkMarketplace is /*ERC1155*/ AssetMinter {

    uint public immutable erc20Supply;
    //----------


    event MarketplaceCutChanged(uint oldVal, uint newVal);
    //---------

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

}