// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./RunnerToken.sol";
import "./EnergyToken.sol";

struct Type {
    uint id;
    uint bonus;
    uint rarity;
}

interface RunnerNFT is IERC721 {
    function getTypeByTokenId(uint id) external view returns (Type memory);
}


// MasterChef is the master of Energy. He can make Energy and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Energy is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ERC721Holder {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 runner;         // Runner amount
        uint256 speed;          // User speed
        uint nftId;
        //
        // We do some fancy math here. Basically, any point in time, the amount of Energys
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.speed * pool.accEnergyPerSpeed) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws. Here's what happens:
        //   1. The pool's `accEnergyPerSpeed` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `speed` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalRunner;
        uint256 totalSpeed;
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Energys to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Energys distribution occurs.
        uint256 accEnergyPerSpeed;   // Accumulated Energys per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The ENERGY TOKEN!
    EnergyToken public energy;
    
    // The RUNNER TOKEN!
    RunnerToken public runner;
    
    // The NFT TOKEN!
    RunnerNFT public nft;
    
    // Dev address.
    address public devaddr;
    // ENERGY tokens created per block.
    uint256 public energyPerBlock;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Energy mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        EnergyToken _energy,
        RunnerToken _runner,
        RunnerNFT _nft,
        address _devaddr,
        address _feeAddress,
        uint256 _energyPerBlock,
        uint256 _startBlock
    ) public {
        require(_devaddr != address(0), "address can't be 0");
        require(_feeAddress != address(0), "address can't be 0");
        
        runner = _runner;
        energy = _energy;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        energyPerBlock = _energyPerBlock;
        startBlock = _startBlock;
        nft = _nft;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            totalRunner:0,
            totalSpeed:0,
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accEnergyPerSpeed: 0,
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's ENERGY allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // View function to see pending ENERGYs on frontend.
    function pendingEnergy(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accEnergyPerSpeed = pool.accEnergyPerSpeed;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockAmount = block.number.sub(pool.lastRewardBlock);
            uint256 energyReward = blockAmount.mul(energyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accEnergyPerSpeed = accEnergyPerSpeed.add(energyReward.mul(1e12).div(pool.totalSpeed));
        }
        return user.speed.mul(accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.totalSpeed == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blockAmount = block.number.sub(pool.lastRewardBlock);
        uint256 energyReward = blockAmount.mul(energyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        energy.mint(devaddr, energyReward.div(10));
        energy.mint(address(this), energyReward);
        pool.accEnergyPerSpeed = pool.accEnergyPerSpeed.add(energyReward.mul(1e12).div(pool.totalSpeed));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for ENERGY allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeEnergyTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
        }
        
        updateSpeed(_pid);
        
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeEnergyTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        updateSpeed(_pid);
        
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    // Deposit Runner to MasterChef to Speed UP :).
    function depositRunner(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeEnergyTransfer(msg.sender, pending);
            }
        }
        
        if(_amount > 0) {
            IBEP20(runner).safeTransferFrom(address(msg.sender), address(this), _amount);
            user.runner = user.runner.add(_amount);
            pool.totalRunner = pool.totalRunner.add(_amount);
            updateSpeed(_pid);
        }
    
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }
    
        // Withdraw Runner from MasterChef.
    function withdrawRunner(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeEnergyTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            safeRunnerTransfer(address(msg.sender), _amount);
            user.runner = user.runner.sub(_amount);
            pool.totalRunner = pool.totalRunner.sub(_amount);
            updateSpeed(_pid);
        }
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    function depositNFT(uint256 _pid, uint _nftId) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeEnergyTransfer(msg.sender, pending);
            }
        }
        if (user.nftId == 0) {
            nft.safeTransferFrom(address(msg.sender), address(this), _nftId);
            user.nftId = _nftId;
        }
        updateSpeed(_pid);	
    
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Deposit(msg.sender, _pid, 1);
    }
    
     function withdrawNFT(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.nftId > 0, "user has no NFT");
        
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.speed.mul(pool.accEnergyPerSpeed).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeEnergyTransfer(msg.sender, pending);
            }
        }
        
        nft.transferFrom(address(this), address(msg.sender), user.nftId);
        user.nftId = 0;
        updateSpeed(_pid);
    
        user.rewardDebt = user.speed.mul(pool.accEnergyPerSpeed).div(1e12);
        emit Withdraw(msg.sender, _pid, 1);
    }
    
    function updateSpeed(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        
        uint256 oldSpeed = user.speed;
            
        if (pool.totalRunner == 0 || user.runner == 0) {
            user.speed = user.amount;
        } else {
            uint256 speedKof = user.runner.mul(10000).mul(lpSupply).div(pool.totalRunner).div(user.amount).add(10000);
            if (speedKof > 30000) {
                speedKof = 30000;
            }    
            speedKof = speedKof.div(10000);
            
            user.speed = user.amount.mul(speedKof);
        }
        
        if (user.nftId > 0) {
            uint bonus = nft.getTypeByTokenId(user.nftId).bonus % 100;
            user.speed = user.speed + user.speed.mul(bonus).div(100);
        }
            
        
        pool.totalSpeed = pool.totalSpeed.add(user.speed).sub(oldSpeed);
    }
    
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        pool.totalSpeed = pool.totalSpeed.sub(user.speed);
        pool.totalRunner = pool.totalRunner.sub(user.runner);
        uint256 amount = user.amount;
        user.speed = 0;
        user.amount = 0;
        user.runner = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe energy transfer function, just in case if rounding error causes pool to not have enough ENERGYs.
    function safeEnergyTransfer(address _to, uint256 _amount) internal {
        uint256 energyBal = energy.balanceOf(address(this));
        if (_amount > energyBal) {
            energy.transfer(_to, energyBal);
        } else {
            energy.transfer(_to, _amount);
        }
    }
    
     // Safe Runner transfer function, just in case if rounding error causes pool to not have enough RUNNERs.
    function safeRunnerTransfer(address _to, uint256 _amount) internal {
        uint256 runnerBal = runner.balanceOf(address(this));
        if (_amount > runnerBal) {
            runner.transfer(_to, runnerBal);
        } else {
            runner.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function setFeeAddress(address _feeAddress) public{
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _energyPerBlock) public onlyOwner {
        massUpdatePools();
        energyPerBlock = _energyPerBlock;
    }
}
