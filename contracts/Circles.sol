// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import './libraries/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

interface IERC20Ext is IERC20 {
    function decimals() external returns (uint);
}

// The goal of this farm is to allow a stake SEANCE earn anything model
// In a flip of a traditional farm, this contract only accepts SEANCE as the staking token
// Each new pool added is a new reward token, each with its own start times
// end times, and rewards per second.
contract Circles is Ownable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 RewardToken;       // reward token contract.
        uint256 RewardPerSecond;   // reward token per second for this pool
        uint256 TokenPrecision; // precision factor used for calculations, dependent on a tokens decimals
        uint256 seanceStaked; // # of seance allocated to this pool
        uint256 lastRewardTime;  // most recent time reward distribution time.
        uint256 accRewardPerShare; // reward per share, times the pools token precision.
        uint256 endTime;
        uint256 startTime; 
        uint256 userLimitEndTime;
        address DAO;
    }

    IERC20 public immutable seance;
    uint public baseUserLimitTime = 2 days;
    uint public baseUserLimit = 0;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetRewardPerSecond(uint _pid, uint256 _gemsPerSecond);

    constructor(IERC20 _seance) {
        seance = _seance;
    }


    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to, PoolInfo memory pool) internal pure returns (uint256) {
        _from = _from > pool.startTime ? _from : pool.startTime;
        if (_from > pool.endTime || _to < pool.startTime) {
            return 0;
        }
        if (_to > pool.endTime) {
            return pool.endTime - _from;
        }
        return _to - _from;
    }

    // VIEW | PENDING REWARDS
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        
        if (block.timestamp > pool.lastRewardTime && pool.seanceStaked != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp, pool);
            uint256 reward = multiplier * pool.RewardPerSecond;
            accRewardPerShare += (reward * pool.TokenPrecision) / pool.seanceStaked;
        }
        return (user.amount * accRewardPerShare / pool.TokenPrecision) - user.rewardDebt;
    }

    // ALLOCATE | ALL POOLS
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // ALLOCATE | SELECT POOL
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        if (pool.seanceStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp, pool);
        uint256 reward = multiplier * pool.RewardPerSecond;

        pool.accRewardPerShare += reward * pool.TokenPrecision / pool.seanceStaked;
        pool.lastRewardTime = block.timestamp;
    }

    // DEPOSIT | TOKENS
    function deposit(uint256 _pid, uint256 _amount) external {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if(baseUserLimit > 0 && block.timestamp < pool.userLimitEndTime) {
            require(user.amount + _amount <= baseUserLimit, "deposit: user has hit deposit cap");
        }

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare / pool.TokenPrecision) - user.rewardDebt;

        user.amount += _amount;
        pool.seanceStaked += _amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / pool.TokenPrecision;

        if(pending > 0) {
            safeTransfer(pool.RewardToken, msg.sender, pending);
        }

        seance.safeTransferFrom(address(msg.sender), address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // WITHDRAW | TOKENS
    function withdraw(uint256 _pid, uint256 _amount) external {  
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare / pool.TokenPrecision) - user.rewardDebt;

        user.amount -= _amount;
        pool.seanceStaked -= _amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / pool.TokenPrecision;

        if(pending > 0) {
            safeTransfer(pool.RewardToken, msg.sender, pending);
        }

        safeTransfer(seance, address(msg.sender), _amount);
        
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // SAAFETY | PREVENTS ROUNDING ERROR
    function safeTransfer(IERC20 token, address _to, uint256 _amount) internal {
        uint256 bal = token.balanceOf(address(this));
        if (_amount > bal) {
            token.safeTransfer(_to, bal);
        } else {
            token.safeTransfer(_to, _amount);
        }
    }

    // ADMIN FUNCTIONS //

    function changeEndTime(uint _pid, uint32 addSeconds) external onlyOwner {
        poolInfo[_pid].endTime += addSeconds;
    }

    function stopReward(uint _pid) external onlyOwner {
        poolInfo[_pid].endTime = block.number;
    }

    function changePoolUserLimitEndTime(uint _pid, uint _time) external onlyOwner {
        poolInfo[_pid].userLimitEndTime = _time;
    }

    function changeUserLimit(uint _limit) external onlyOwner {
        baseUserLimit = _limit;
    }

    function changeBaseUserLimitTime(uint _time) external onlyOwner {
        baseUserLimitTime = _time;
    }

    function checkForToken(IERC20 _Token) private view {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].RewardToken != _Token, "checkForToken: reward token provided");
        }
    }

    function recoverWrongTokens(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(seance), "recoverWrongTokens: Cannot be seance");
        checkForToken(IERC20(_tokenAddress));
        
        uint bal = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), bal);

        emit AdminTokenRecovery(_tokenAddress, bal);
    }

    function emergencyRewardWithdraw(uint _pid, uint256 _amount) external onlyOwner {
        poolInfo[_pid].RewardToken.safeTransfer(poolInfo[_pid].DAO, _amount);
    }

    // ADD | NEW POOL
    function add(
        uint _rewardPerSecond, 
        IERC20Ext _Token, 
        uint _startTime, 
        uint _endTime, 
        address _DAO) external onlyOwner {

        checkForToken(_Token); // ensure you cannot add duplicate pools

        uint lastRewardTime = block.timestamp > _startTime ? block.timestamp : _startTime;
        uint decimalsRewardToken = _Token.decimals();
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        uint precision = 10**(30 - decimalsRewardToken);

        poolInfo.push(PoolInfo({
            RewardToken: _Token,
            RewardPerSecond: _rewardPerSecond,
            TokenPrecision: precision,
            seanceStaked: 0,
            startTime: _startTime,
            endTime: _endTime,
            lastRewardTime: lastRewardTime,
            accRewardPerShare: 0,
            DAO: _DAO,
            userLimitEndTime: lastRewardTime + baseUserLimitTime
        }));
    }

    // UPDATE | REWARD RATE
    function setRewardPerSecond(uint256 _pid, uint256 _rewardPerSecond) external onlyOwner {
        
        updatePool(_pid);
        poolInfo[_pid].RewardPerSecond = _rewardPerSecond;

        emit SetRewardPerSecond(_pid, _rewardPerSecond);
    }

}
