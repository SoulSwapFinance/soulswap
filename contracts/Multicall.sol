// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
    function _msgData() internal view virtual returns (bytes calldata) { return msg.data; }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;
    uint private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }
    function totalSupply() public view virtual override returns (uint) { return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint) { return _balances[account]; }
    function transfer(address recipient, uint amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, 'ERC20: transfer amount exceeds allowance');
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool) {
        uint currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, 'ERC20: decreased allowance below zero');
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint amount) internal virtual {
        require(sender != address(0), 'ERC20: transfer from the zero address');
        require(recipient != address(0), 'ERC20: transfer to the zero address');
        _beforeTokenTransfer(sender, recipient, amount);
        uint senderBalance = _balances[sender];
        require(senderBalance >= amount, 'ERC20: transfer amount exceeds balance');
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint amount) internal virtual {
        require(account != address(0), 'ERC20: mint to the zero address');
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint amount) internal virtual {
        require(account != address(0), 'ERC20: burn from the zero address');
        _beforeTokenTransfer(account, address(0), amount);
        uint accountBalance = _balances[account];
        require(accountBalance >= amount, 'ERC20: burn amount exceeds balance');
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint amount) internal virtual {
        require(owner != address(0), 'ERC20: approve from the zero address');
        require(spender != address(0), 'ERC20: approve to the zero address');
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint amount) internal virtual {}
}

contract Multicall {

    ERC20 public immutable wftm = ERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    ERC20 public immutable fusd = ERC20(0xAd84341756Bf337f5a0164515b1f6F993D194E1f);

    address public ftmFusdPool = 0x11b5B41b55724427B44A8625AE14F24e0CaAD586;
    address public summoner;
    address private buns = msg.sender;

    bool isInitialized;
    event Initialized(address summoner);

    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function initialize(address _summoner) public {
        require(msg.sender == buns, 'only buns');
        require(!isInitialized, 'already initialized');

        summoner = _summoner;
        isInitialized = true;

        emit Initialized(summoner);
    }

    function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "aggregate: call failed");
            returnData[i] = ret;
        }
    }

    function blockAndAggregate(
        Call[] memory calls) public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(true, calls);
    }

    function tryAggregate(bool requireSuccess, Call[] memory calls) public returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            if (requireSuccess) { require(success, "aggregate: call failed"); }
            returnData[i] = Result(success, ret);
        }
    }

    function tryBlockAndAggregate(bool requireSuccess, Call[] memory calls) 
        public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
            blockNumber = block.number;
            blockHash = blockhash(block.number);
            returnData = tryAggregate(requireSuccess, calls);
    }
    
    // helper functions
    function getEthBalance(address addr) public view returns (uint balance) {
        balance = addr.balance;
    }

    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    function getBlockHash(uint blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }
    
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(block.number - 1);
    }

    function getCurrentBlockTimestamp() public view returns (uint timestamp) {
        timestamp = block.timestamp;
    }
    
    function getCurrentTime() public view returns (uint currentTime) {
        currentTime = block.timestamp;
    }

    function getNextDay() public view returns (uint nextDay) {
        nextDay = block.timestamp + 1 days;
    }

    function getFutureTime(uint _futureDays) public view returns (uint futureTime) {
        futureTime = block.timestamp + (_futureDays * 1 days);
    }

    function getTimespan(uint _startTime, uint _endTime) public pure returns (uint timespan) {
        require(_endTime > _startTime, 'the egg does not precede the chicken');
        timespan = _endTime - _startTime;
    }

    function getCurrentBlockDifficulty() public view returns (uint difficulty) {
        difficulty = block.difficulty;
    }

    function getCurrentBlockGasLimit() public view returns (uint gaslimit) {
        gaslimit = block.gaslimit;
    }

    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    function getTokenBalance(ERC20 token, address account) public view returns (uint balance) {
        balance = token.balanceOf(account);
    }

    // acquires sum of stableCoins in pool (e.g. fusd, usdc) and returns total value of pool wrt stableCoin
    function getDollarValue(ERC20 stableCoin, address pool) public view returns (uint value) {
        value = stableCoin.balanceOf(pool) * 2;
    }

    function getFtmValue(address pool) public view returns (uint value) {
        value = wftm.balanceOf(pool) * 2;
    }

    function getFusdValue(address pool) public view returns (uint value) {
        value = fusd.balanceOf(pool) * 2;
    }

    function getFtmFusdValue() public view returns (uint value) {
        value = fusd.balanceOf(ftmFusdPool) * 2;
    }

    function getValueLocked(ERC20 pool) public view returns (uint value) {
        uint lockedAmount = pool.balanceOf(summoner);
        uint fusdValue = getFusdValue(address(pool));      // gets value in FUSD ($)
        uint ftmValue = getFtmValue(address(pool));       // gets value in FTM
        uint ftmUsdValue = getFtmFusdValue(); // gets ftm USD($) value

        bool isFusdPool = fusdValue >= ftmValue;

        uint lpValue = isFusdPool        // checks if fusd pool
            ? fusdValue                 // if fusd pool --> get fusdValue
            : ftmValue * ftmUsdValue;                // if ftm pool --> get ftmValue
        
        value = lpValue * lockedAmount; // value ($) of each lp * amount locked
    }
}