window.addEventListener('load', async () => {
  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (window.ethereum) {
    window.web3 = new Web3(window.ethereum);

    try {
      // Request account access
      await window.ethereum.enable();

      const contractABI = 'TODO_CONTRACT_ABI';
      const contractAddress = 'TODO_CONTRACT_ADDRESS';

      const contract = new web3.eth.Contract(contractABI, contractAddress);

      const _soundAsset = { name: SOUND_ASSET_NAME,
                             format: 'format..',
                             mediaFiles: 'files..',
                             tempo: 122,
                             genre: 'genre..',
                             style: 'style..',
                             baseNote: 'note..',
                             signature: 'signature..',
                             authorAddress: ASSET_OWNER_ACCOUNT };


      async function createAsset() {
        const txHash = await contract.methods.createSoundAsset(_soundAsset).send({ from: MARKETPLACE_OWNER_ACCOUNT });
        console.log(`Transaction hash: ${txHash}`);
      }

      async function offerAssetForSale(assetId) {
        // TODO: verify selectedAddress is assetId owner
        const txHash = await contract.methods.offerAssetForSale(assetId, assetPrice, timeInSeconds).send({ from: window.ethereum.selectedAddress });
        console.log(`Transaction hash: ${txHash}`);
      }

      async function purchaseAsset(assetId) {
        // TODO: verify that the Eth value is >= assetPrice
        const txHash = await contract.methods.purchaseAsset(assetId).send({ from: window.ethereum.selectedAddress });
        console.log(`Transaction hash: ${txHash}`);
      }

      async function placeAssetInAuction() {
        // TODO: verify selectedAddress is assetId owner
        const txHash = await contract.methods.placeAssetInAuction(assetId, assetPrice, timeInSeconds).send({ from: window.ethereum.selectedAddress });
        console.log(`Transaction hash: ${txHash}`);
      }

      async function placeBidForAssetInAuction(assetId, bidAmount) {
        // TODO: verify that the Eth value is >= current auction price
        const txHash = await contract.methods.placeBidForAssetInAuction(assetId, bidAmount).send({ from: window.ethereum.selectedAddress });
        console.log(`Transaction hash: ${txHash}`);
      }

      async function completeAuction(assetId) {
        // TODO: make sure auction end-time has been reached
        const txHash = await contract.methods.completeAuction(assetId).send({ from: window.ethereum.selectedAddress });
        console.log(`Transaction hash: ${txHash}`);
      }

    } catch (error) {
      console.error("User denied account access...");
    }
  } else {
    console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
  }
});
