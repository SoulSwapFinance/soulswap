// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;


// File: @openzeppelin/contracts/utils/Context.sol

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }

    function _msgData() internal view virtual returns (bytes calldata) { return msg.data; }
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


abstract contract IERC20 {
    function totalSupply() external virtual view returns (uint256);
    function balanceOf(address tokenOwner) external virtual view returns (uint256 balance);
    function allowance(address tokenOwner, address spender) external virtual view returns (uint256 remaining);
    function transfer(address to, uint256 tokens) external virtual returns (bool success);
    function approve(address spender, uint256 tokens) external virtual returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) external virtual returns (bool success);
    function burnFrom(address account, uint256 amount) public virtual;
    
    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}

contract Recovery is Ownable {

    address public grimAddress;
    address public soulAddress;
    
    address[] public whitelist;

    event WhitelistUpdated(address indexed recipient, bool indexed access);
    event recovered(address indexed recipient, uint amount);

    mapping(address => bool) public whitelisted;

    // maps grimLP to soulLP
    mapping(address => address) public tokens;
    
    modifier onlyWhitelisted() {
        address msgSender = _msgSender();
        require(whitelisted[msgSender], "not whitelisted");
        _;
    }

    function initialize(address _grimAddress, address _soulAddress) public onlyOwner {
        grimAddress = _grimAddress;
        soulAddress = _soulAddress;
    }
    
    function recover() public onlyWhitelisted {
        // get amount as balance of sender.
        uint amount = IERC20(grimAddress).balanceOf(address(msg.sender));

        // ensure the user has enough grimLP to exchange.
        require(IERC20(grimAddress).balanceOf(address(msg.sender)) >= amount, 'insufficient balance');

        // ensures this contract has enough soulLP to send.
        require(IERC20(soulAddress).balanceOf(address(this)) >= amount, 'insufficient liquidity');

        // internal function to burn grimLP then transfer soulLP to the user.
        _recover(amount);
    }
    
    function _recover(uint256 _amount) internal {
        // [1] burns the grimLP from the user
        IERC20(grimAddress).burnFrom(msg.sender, _amount);

        // [2] transfers the soulLP from the user
        IERC20(soulAddress).transfer(msg.sender, _amount);
        
        emit recovered(msg.sender, _amount);
    }

    function removeRecipient(address _recipient) public virtual onlyOwner {
        require(whitelisted[_recipient], 'not whitelisted');

        // remove: recipient from whitelist
        whitelisted[_recipient] = false;

        for (uint8 i; i < whitelist.length; i++) {
            if (whitelist[i] == _recipient) {
                whitelist[i] = whitelist[i+1];
                whitelist.pop();

                emit WhitelistUpdated(_recipient, false);
                return;
            }
        }
    }

    function addRecipient(address _recipient) public virtual onlyOwner {
        require(!whitelisted[_recipient], 'already whitelisted');

        // add: recipient to whitelist
        whitelisted[_recipient] = true;

        whitelist.push(_recipient);

        emit WhitelistUpdated(_recipient, true);
    }

    function addToken(address _grimLP, address _soulLP) public virtual onlyOwner {
        require(!tokens[_recipient], 'already whitelisted');

        // add: recipient to whitelist
        whitelisted[_recipient] = true;

        whitelist.push(_recipient);

        emit WhitelistUpdated(_recipient, true);
    }
}