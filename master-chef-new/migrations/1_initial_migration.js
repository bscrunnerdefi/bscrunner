
const MasterChef = artifacts.require('MasterChef');
const Timelock = artifacts.require('Timelock');

module.exports = async function (deployer) {

	  await deployer.deploy(Timelock, "0x542FD1EF5B9594118BCd076A552d6C04d9e4A07C", 108000);
	  await deployer.deploy(MasterChef,
			"0x1A566DD84262D51c7543a85408a8452BEe025841",
			"0xB9E5300cb0C3a8e0b650c804495C9ae35424C248",
			"0x55Bb71382BAbdEe7f62E8B10FeAF41F94D8c8fCc",
			"0xc181e80419533cE3d81f8fBe5ad199ac21649268",
			"0x584Dc3fCdbF5A3b592E63BF80e5d179C78d0b981", 
			"1000000000000000000", 5731410);
	    await (await MasterChef.deployed()).transferOwnership("0x542FD1EF5B9594118BCd076A552d6C04d9e4A07C");

};