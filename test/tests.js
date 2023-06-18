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

   beforeEach( async function () {
        instance = await Soundwork.deployed(); // deploy a dedicated instance for payment tokens
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
     const ASSET_OWNER = addr3;
     const assetInd = await safe_createSoundAsset(ASSET_OWNER);
          
     await verifyNonOwnerCannotOffetAssetForPurchase(assetInd);

     await verifyCannotPurchaseNonOfferedAsset(assetInd);

     // now offer asset:
     await instance.offerAssetForSale(assetInd, PURCHASE_PRICE.toString(), 100, 
                    { from: ASSET_OWNER});

     await verifyCannotPurchaseIfPriceTooLow(assetInd, PURCHASE_PRICE);

     await verifyCannotPurchaseIfMarketplaceNotApproved(assetInd, PURCHASE_VALUE);

     // now approve marketplace for all of owner's asssets:
     const MARKETPLACE_ADDRESS = instance.address;
     await instance.setApprovalForAll( MARKETPLACE_ADDRESS, true, {from: ASSET_OWNER});

     // and purchase:
     await instance.purchaseAsset(assetInd, { from: addr2, value: emoughPrice});

  });

  async function verifyCannotPurchaseIfMarketplaceNotApproved(assetInd, emoughPrice) {
     try { 
          await instance.purchaseAsset(assetInd, { from: addr2, value: emoughPrice});
          assert.fail( "cannot buy unless marketplace is approved by asset owner");
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

  async function safe_createSoundAsset(assetOwner) {
     soundAsset.authorAddress = assetOwner;
     await instance.createSoundAsset( soundAsset, {from: addr1});
     const assetInd = 1;
     let assetRecord = await instance.soundAssets(assetInd);
     assert.equal( assetRecord.name, SOUND_ASSET_NAME);
     console.log(`assetRecord: ${assetRecord.name}`);
     return assetInd;
  }

});

