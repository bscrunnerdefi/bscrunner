const RunnerToken = artifacts.require("RunnerToken");
const RunnerNFT = artifacts.require("RunnerNFT");
const RunnerManager = artifacts.require("RunnerManager");

module.exports = async function (deployer) {
  await deployer.deploy(RunnerToken)
  await deployer.deploy(RunnerNFT)
  await deployer.deploy(RunnerManager, "0x1A566DD84262D51c7543a85408a8452BEe025841", RunnerToken.address, RunnerNFT.address)
  await (await RunnerToken.deployed()).transferOwnership(RunnerManager.address)
  await (await RunnerNFT.deployed()).transferOwnership(RunnerManager.address)
    await (await RunnerManager.deployed()).addNFTType(0,5,1)
    await (await RunnerManager.deployed()).addNFTType(1,10,2)
    await (await RunnerManager.deployed()).addNFTType(2,20,3)
    await (await RunnerManager.deployed()).addNFTType(3,30,4)
};
