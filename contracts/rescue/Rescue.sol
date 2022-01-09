// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

// File: @openzeppelin/contracts/utils/Address.sol

library Address {

    function isContract(address account) internal view returns (bool) {

        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: contracts/libraries/SafeERC20.sol

library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint value
    ) internal {
        uint newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint value
    ) internal {
            uint oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/utils/Context.sol

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: contracts/libraries/ERC20.sol

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

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        
        return true;
    }

    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool) {
        uint currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual {}
}

// File: @openzeppelin/contracts/access/Ownable.sol

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/Rescue.sol

contract Rescue is Ownable {

    using SafeERC20 for IERC20;

    struct Safe {
        IERC20 soulLP;
        IERC20 grimLP;
        address recipient;
        uint amount;
        bool withdrawn;
    }

    struct Conversion {
        IERC20 soulLP;
        IERC20 grimLP;
    }

    // An array of 'Conversion' structs
    Conversion[] public conversions;

    uint public depositsCount;
    bool public isInitialized;

    mapping (address => uint[]) public depositsByRecipient;
    mapping (address => uint[]) private depositsByTokenAddress;

    mapping (uint => Safe) public safes;
    mapping (address => uint) public walletBalance;
    mapping (address => mapping(address => uint)) public walletTokenBalance;
    
    event Withdraw(address recipient, uint amount);
    event Rescued(uint amount, uint id);

    // add Conversion
    function addConversion(IERC20 _soulLP, IERC20 _grimLP) public onlyOwner {
            conversions.push(Conversion(_soulLP, _grimLP));
    }

    // update Conversion
    function updateConversion(uint _index, IERC20 _grimLP) public onlyOwner {
        Conversion storage conversion = conversions[_index];
        conversion.grimLP = _grimLP;
    }
        
    function lockSouls(IERC20 _soulLP, IERC20 _grimLP, address _recipient, uint _amount) 
        external onlyOwner returns (uint id) {

        require(_amount > 0, 'Insufficient amount.');
        // require(_soulLP.allowance(msg.sender, address(this)) >= _amount, 'Approve SoulLP first.');

        // [0] soulLP balance [before the deposit].
        // uint beforeDeposit = _soulLP.balanceOf(address(this));

        // [1-A] transfers your soulLP into a Safe.
        // _soulLP.transferFrom(msg.sender, address(this), _amount);

        // [1-B] soulLP balance [after the deposit].
        // uint afterDeposit = _soulLP.balanceOf(address(this));
        
        // [1-C] safety precaution (requires contract recieves SoulLP).
        // _amount = afterDeposit - beforeDeposit; 
              
        // [2-A] updates (adds) the walletBalance of the recipient.
        walletBalance[_recipient] += _amount;

        // [2-B] updates (adds) the walletTokenBalance of the recipient.
        walletTokenBalance[address(_soulLP)][_recipient] = walletTokenBalance[address(_soulLP)][_recipient] + _amount;
        
        // [3] creates a new id, based off deposit count [id].
        id = ++depositsCount;
        safes[id].soulLP = _soulLP;
        safes[id].grimLP = _grimLP;
        safes[id].recipient = _recipient;
        safes[id].amount = _amount;
        safes[id].withdrawn = false;
        
        depositsByRecipient[_recipient].push(id);
        depositsByTokenAddress[address(_soulLP)].push(id);

        emit Rescued(_amount, id);
        
        return id;
    }

    // initializes contract for withdrawals.
    function initialize() public onlyOwner {
        isInitialized == false ? isInitialized = true : isInitialized = false;
    }

    function withdrawTokens(uint id) public {
        // [0] ensures contract is Initialized.
        require(isInitialized, 'Not initialized');

        // stores safes data into "safe".
        Safe storage safe = safes[id];

        // requires sender is recipient.
        require(msg.sender == safe.recipient, 'You are not the recipient.');
        require(!safe.withdrawn, 'Tokens are already withdrawn.');
        safe.grimLP.approve(address(this), safe.amount);

        // [0-A] updates safe to show withdrawn.
        safe.withdrawn = true;
        
        // [0-B] reduces the soulLP balance of user from safe [walletBalance].
        walletBalance[msg.sender] -= safe.amount;

        // [0-C] reducess the soulLP balance of user from safe [walletTokenBalance].
        walletTokenBalance[address(safe.soulLP)][msg.sender] -= safe.amount;

        // [1] transfers grimLP to enable recipient to claim.
        safe.grimLP.transferFrom(msg.sender, address(this), safe.amount);

        // [2] transfers soulLP to the sender.
        safe.soulLP.transfer(msg.sender, safe.amount);

        emit Withdraw(msg.sender, safe.amount);  
    }
    
    function getDepositsByTokenAddress(address _token) view external returns (uint[] memory) { 
        return depositsByTokenAddress[_token]; 
    }

    function getDepositsByRecipient(address _recipient) view external returns (uint[] memory) { 
        return depositsByRecipient[_recipient]; 
    }

    function getTotalLockedBalance(uint id) view external returns (uint) { 
        return safes[id].soulLP.balanceOf(address(this)); 
    }
    
    // in order to burn grimLP -- recovers any token from contract.
    function recoverToken( address _token ) external onlyOwner returns ( bool ) {
        address owner = owner();
        IERC20( _token ).safeTransfer( owner, IERC20( _token ).balanceOf( address(this) ) );

        return true;
    }

    function enWei(uint amount) public pure returns (uint) { return amount * 1E18; }
    function fromWei(uint amount) public pure returns (uint) { return amount / 1E18; }

}
