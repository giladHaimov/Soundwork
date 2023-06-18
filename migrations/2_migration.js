//truffle migrate --compile-none --reset
const Soundwork = artifacts.require("./contracts/SoundworkMarketplace.sol");


module.exports = async function(deployer) {
  // zzzz set params below
  await deployer.deploy(Soundwork, 2, '1000000000000', "place-uri-here");
};