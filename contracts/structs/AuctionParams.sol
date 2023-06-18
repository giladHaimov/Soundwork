// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

struct AuctionParams {
    address origOwner;
    address lastBidder;
    uint minPrice;
    uint lastBiddingPrice;
    uint endDate;
}

