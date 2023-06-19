//ganache-cli --fork --port 9545 https://mainnet.infura.io/v3/46b5f53c4fb7487f8a964120bcfb43ff

const Web3 = require('web3');
const BN = require('bn.js');
const { expectEvent, expectRevert }  = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');

const Soundwork = artifacts.require("./contracts/SoundworkMarketplace.sol");

contract("SoundworkMarketplace", (accounts_) => {

   const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

   const STR20 = '123456789.123456789.';

   function toBigNum( val) {
        return new BN(Web3.utils.toWei( val, 'gwei'));
        //return Web3.utils.fromWei( val, 'gwei');
   }

   const PURCHASE_PRICE = '10000000000';
   const PURCHASE_VALUE = '20000000000';

   //---

   const addr1 = accounts_[0];
   let   addr2 = accounts_[1];
   let   addr3 = accounts_[2];
   let   addr4 = accounts_[3];

   const SOUND_ASSET_NAME = "my-sound-asset";

   const soundAsset = { name: SOUND_ASSET_NAME,
                         format: STR20, 
                         mediaFiles: STR20 , 
                         tempo: 122,      
                         genre: STR20, 
                         style: STR20, 
                         baseNote: STR20, 
                         signature: STR20, 
                         authorAddress: addr1 };

   let instance;

  //======================== test methods ========================

  let MARKETPLACE_ADDRESS;

   beforeEach( async function () {
        instance = await Soundwork.deployed(); // deploy a dedicated instance for payment tokens

        MARKETPLACE_ADDRESS = instance.address
   });


  it("verify marketplace owner can create sound asset", async () => { //
     await instance.createSoundAsset( soundAsset, {from: addr1});
  });

  it("verify non-owner cannot create sound asset", async () => { //
     try { 
          await instance.createSoundAsset( soundAsset, {from: addr2});
          assert.fail( "non-owner cannot create sound asset");
     } catch(err) {
          // should fail!
     }
  });

  it("offer and purchase a sound asset", async () => { //
     const ORIG_ASSET_OWNER = addr3;
     const assetInd = 2;
     await safe_createSoundAsset(ORIG_ASSET_OWNER, assetInd);
          
     await verifyAssetOwner( assetInd, ORIG_ASSET_OWNER);

     await verifyNonOwnerCannotOffetAssetForPurchase(assetInd);

     await verifyCannotPurchaseNonOfferedAsset(assetInd);

     // now offer asset:
     await instance.offerAssetForSale(assetInd, PURCHASE_PRICE.toString(), 100, 
                    { from: ORIG_ASSET_OWNER});

     await verifyCannotPurchaseIfPriceTooLow(assetInd, PURCHASE_PRICE);

     await verifyCannotPurchaseIfMarketplaceNotApproved(assetInd, PURCHASE_VALUE);

     // now have owner approve marketplace
     await approveMarketplaceForAllOwnerAssets( ORIG_ASSET_OWNER)

     // and purchase:
     const NEW_OWNER = addr2;
     await instance.purchaseAsset(assetInd, { from: NEW_OWNER, value: PURCHASE_VALUE});

     // verify ownership change
     await verifyAssetOwner( assetInd, NEW_OWNER);
     await verifyNotAssetOwner( assetInd, ORIG_ASSET_OWNER);

  }); 

  it("verify auction flow", async () => { //
     const ORIG_ASSET_OWNER = addr4;
     const assetInd = 3;
     await safe_createSoundAsset(ORIG_ASSET_OWNER, assetInd);          
     
     await verifyAssetOwner( assetInd, ORIG_ASSET_OWNER);

     await verifyNonOwnerCannotCreateAuction(assetInd);

     await verifyCannotBidForNonExistingAuction(assetInd);

     // now enter auction:
     await instance.placeAssetInAuction(assetInd, PURCHASE_PRICE.toString(), 100, 
                    { from: ORIG_ASSET_OWNER});

     const auction_ = await instance.assetsInAuction( assetInd);

     await verifyCannotBidOnAuctionIfPriceTooLow(assetInd, PURCHASE_PRICE);

     await verifyCannotBidOnAuctionIfMarketplaceNotApproved(assetInd, PURCHASE_VALUE);

     await verifyCannotCompleteAuctionBeforeTime(assetInd);

     // now have owner approve markeyplace
     await approveMarketplaceForAllOwnerAssets( ORIG_ASSET_OWNER);

     console.log(`2/auction_ min price: ${auction_.minPrice}`);
     console.log(`2/auction_ endDate: ${auction_.endDate}`);

     // and place bid on auction:
     const NEW_OWNER = addr2;
     await instance.placeBidForAssetInAuction(assetInd, { from: NEW_OWNER, value: PURCHASE_VALUE});

     // verify asset ownership not changed
     await verifyAssetOwner( assetInd, ORIG_ASSET_OWNER);

     await verifyCannotCompleteAuctionBeforeTime(assetInd);

     
     // finally use a debug gateway to fix completion time so auction can be closed:
     /* 
     //await instance.debug_forceSetAuctionCompleteTime(assetInd, { from: addr1});

     await instance.completeAuction(assetInd, { from: addr3});

     await verifyAssetOwner( assetInd, NEW_OWNER);
     await verifyNotAssetOwner( assetInd, ORIG_ASSET_OWNER);
     */          

  }); 


  //-----------


  async function verifyCannotPurchaseIfMarketplaceNotApproved(assetInd, enoughPrice) {
     try { 
          await instance.purchaseAsset(assetInd, { from: addr2, value: enoughPrice});
          assert.fail( "cannot buy unless marketplace is approved by asset owner");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotCompleteAuctionBeforeTime(assetInd) {
     try { 
          await instance.completeAuction(assetInd, { from: addr2});
          assert.fail( "should not be able to complete auction before time");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotBidOnAuctionIfMarketplaceNotApproved(assetInd, enoughPrice) {
     try { 
          await instance.placeBidForAssetInAuction( assetInd, { from: addr2, value: enoughPrice});
          assert.fail( "cannot bid unless marketplace is approved by asset owner");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotBidOnAuctionIfPriceTooLow(assetInd, tooLowPrice) {
     try { 
          await instance.placeBidForAssetInAuction(assetInd, { from: addr2, value: tooLowPrice});
          assert.fail( "cannot bid if price too low");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotPurchaseIfPriceTooLow(assetInd, tooLowPrice) {
     try { 
          await instance.purchaseAsset(assetInd, { from: addr2, value: tooLowPrice});
          assert.fail( "cannot buy if price too low");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyNonOwnerCannotCreateAuction(assetInd) {
     try { 
          await instance.placeAssetInAuction(assetInd, PURCHASE_PRICE, 100, { from: addr2});
          assert.fail( "cannot auction asset unless owner");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotBidForNonExistingAuction(assetInd) {
     try { 
          await instance.placeBidForAssetInAuction(assetInd, { from: addr2, value: PURCHASE_VALUE});
          assert.fail( "cannot bid if no auction");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyNonOwnerCannotOffetAssetForPurchase(assetInd) {
     try { 
          await instance.offerAssetForSale(assetInd, PURCHASE_PRICE, 100, { from: addr2});
          assert.fail( "cannot offer asset unless owner");
     } catch(err) {
          // should fail!
     }
  }

  async function verifyCannotPurchaseNonOfferedAsset(assetInd) {
     try { 
          await instance.purchaseAsset(assetInd, { from: addr2, value: PURCHASE_PRICE});
          assert.fail( "cannot purchase non-offered sound asset");
     } catch(err) {
          // should fail!
     }
  }

  async function safe_createSoundAsset(assetOwner, assetInd) {
     soundAsset.authorAddress = assetOwner;
     assert.equal( soundAsset.authorAddress, assetOwner, "soundAsset.authorAddress not set");
     
     const CONTRACT_OWNER = addr1;
     await instance.createSoundAsset( soundAsset, {from: CONTRACT_OWNER});

     let assetRecord = await instance.soundAssets(assetInd);
     assert.equal( assetRecord.name, SOUND_ASSET_NAME);
     console.log(`assetRecord: ${assetRecord.name}`);

     const ctr_1 = await instance.balanceOf( addr1, assetInd);
     const ctr_2 = await instance.balanceOf( addr2, assetInd);
     const ctr_3 = await instance.balanceOf( addr3, assetInd);
     
     console.log(`==>Addrs  11: ${addr1} , 22: ${addr2}, 33: ${addr3} `);
     console.log(`==>Counts  11: ${ctr_1} , 22: ${ctr_2}, 33: ${ctr_3} `);

     return assetInd;
  }

  async function verifyAssetOwner( assetInd, addr_) {
     const isOwner = await instance.isCurrentNftOwner( addr_, assetInd);
     assert.isTrue( isOwner, "not owner");
  }

  async function verifyNotAssetOwner( assetInd, addr_) {
     const isOwner = await instance.isCurrentNftOwner( addr_, assetInd);
     assert.isFalse( isOwner, "is owner");
  }

  async function approveMarketplaceForAllOwnerAssets( owner_) {
     await instance.setApprovalForAll( MARKETPLACE_ADDRESS, true, {from: owner_});
  }


});

