const RunnerManager = artifacts.require("RunnerManager");

module.exports = async function (deployer) {
  await deployer.deploy(RunnerManager, "0x1A566DD84262D51c7543a85408a8452BEe025841", "0xB9E5300cb0C3a8e0b650c804495C9ae35424C248", "0x55Bb71382BAbdEe7f62E8B10FeAF41F94D8c8fCc")
  await (await RunnerManager.deployed()).transferOwnership("0x542FD1EF5B9594118BCd076A552d6C04d9e4A07C");
};
