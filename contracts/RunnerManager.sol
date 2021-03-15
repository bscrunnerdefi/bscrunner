// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

import "../oz/utils/structs/EnumerableSet.sol";
import "../oz/access/Ownable.sol";
import "./RunnerNFT.sol";
import "./Random.sol";
import "../oz/token/ERC20/ERC20.sol";
import "../oz/token/ERC20/IERC20.sol";
import "../oz/token/ERC20/utils/SafeERC20.sol";

interface IRunnerToken is IERC20 {
    function transferOwnership(address newOwner) external;
    function mint(address _to, uint256 _amount) external;
    function burn(address _to, uint256 _amount) external;
}

contract RunnerManager is Ownable {
    
    using Random for Random.Seed;
    using SafeERC20 for IERC20;
    
    struct Config {
        uint winFactor;
        uint packPrice;
        uint maxPacksPerPurchase;
        uint runnerPerEnergy;
    }
    
    struct Purchase {
        uint numPacks;
        Random.Seed seed;
        uint256 energyReward;
        uint256 runnerReward;
        uint nftSeed;
        uint nftIds;
        uint rand;
    }
    
    event RewardRedeemed(address buyer);
    event Purchased(address buyer, uint numPacks);

    IERC20 public energyToken;
    IRunnerToken public runnerToken;
    RunnerNFT public nft;
    
    mapping(address=>Purchase) public purchases;
    
    Config config = Config(100, 10, 5, 10);
    
    constructor(IERC20 e, IRunnerToken r, RunnerNFT n) {
        energyToken = e;
        runnerToken = r;
        nft = n;
    }

    //owner methods
    function emergencyWithdraw() public onlyOwner {
        uint amount = energyToken.balanceOf(address(this));
        energyToken.safeTransfer(msg.sender, amount);
    }

    function addNFTType(uint nftId, uint bonus, uint rarity) public onlyOwner {
        nft.addType(nftId, bonus, rarity);
    }

    function transferRunnerOwnerTo(address newOwner) public onlyOwner {
        runnerToken.transferOwnership(newOwner);
    }
    
    function transferNFTOwnerTo(address newOwner) public onlyOwner {
        nft.transferOwnership(newOwner);
    }
    
    function setEnergyToken(IERC20 e) public onlyOwner {
         energyToken = e;
    }
    
    //Main functionality
    function exchange(uint amount) public {
        runnerToken.mint(msg.sender, amount * config.runnerPerEnergy);
        energyToken.transferFrom(msg.sender, address(this), amount);
    }
    
    function buy(uint numPacks) public {
        Purchase storage purchase = purchases[msg.sender];
        require(numPacks > 0, "numPacks should be more than 0");
        require(purchase.numPacks == 0, "open packs before making another purchase");
        require(numPacks <= config.maxPacksPerPurchase, "exceeded maximum packs per purchase");
        
        uint price = numPacks * config.packPrice * 1e18;
        
        runnerToken.burn(msg.sender, price);
        
        purchases[msg.sender] = Purchase(numPacks, Random.Seed(block.number), 0, 0, 0, 0, 0);
        
        emit Purchased(msg.sender, numPacks);
    }
    
    function redeem() public {
        Purchase storage purchase = purchases[msg.sender];
        
        require(purchase.numPacks > 0, "purchase packs first");
        require(purchase.seed.isReady(), "purchase packs first");
        
        generateReward();
        
        if (purchase.runnerReward > 0) {
            runnerToken.mint(msg.sender, purchase.runnerReward);        
        }
        
        if (purchase.energyReward > 0) {
            uint energyReward = purchase.energyReward;    
            uint energyBalance = energyToken.balanceOf(address(this));
            if (energyBalance < energyReward) {
                energyReward = energyBalance;
            }
            energyToken.safeTransfer(msg.sender, energyReward);
        }
    
        uint nftSeedIterator = purchase.nftSeed;
        purchase.nftIds = 0;
        for(uint i = 0; i < purchase.numPacks; ++i) {
            uint seed = nftSeedIterator % 1000;
            
            if (seed > 820) {
                uint rarity = 1;
                if (seed == 999) {
                    rarity = 4;
                } else
                if (seed > 980) {
                    rarity = 3;
                } else
                if (seed > 940) {
                    rarity = 2;
                }
            
            
                uint tokenId = nft.createRandomTokenWithRarity(msg.sender, rarity, seed);
                
                purchase.nftIds = purchase.nftIds * 100000 + tokenId;
            }
            nftSeedIterator = nftSeedIterator / 1000;
        }
        
        purchase.numPacks = 0;
        
        emit RewardRedeemed(msg.sender);
    }
    
    function generateReward() public {
        Purchase storage purchase = purchases[msg.sender];
        require(purchase.numPacks > 0, "purchase packs first");
        require(purchase.seed.isReady(), "purchase packs first");
        
        bytes32 seed = purchase.seed.get();
        uint rand = uint(seed) % 100000;        
        purchase.rand = rand;
        uint energyReward = 0;
        uint runnerReward = 0;
        
        uint runnerNumber = rand % 100;
        uint energyNumber = rand / 100 % 100;
        
        if (runnerNumber > 20) {
            runnerReward = 1e18 * (runnerNumber % 10 + 1);
        }
        
        purchase.runnerReward = runnerReward * purchase.numPacks * config.winFactor / 100;
        
        if (energyNumber > 90) {
            energyReward = 1e18 * 5 * config.packPrice * (energyNumber % 10 + 1) / 10;
        } else 
        if (energyNumber > 20) {
            energyReward =  1e18 * config.packPrice * (energyNumber % 10) / 10 / 3;
        }
        energyReward = energyReward / config.runnerPerEnergy;
        purchase.energyReward = energyReward * purchase.numPacks * config.winFactor / 100;
        
        purchase.nftSeed = uint(rehash(seed)) % 1000000000000000000;    
    }
    
    function rehash(bytes32 b32) internal pure returns (bytes32) {
      return sha256(abi.encodePacked(b32));
    }
    
    //Configuration
    
    function setConfig(Config memory _config) public onlyOwner {
        config = _config;
    }
    
    function getConfig() external view returns (Config memory) {
        return config;
    }
}