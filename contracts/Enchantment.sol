// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import './libraries/ERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// enchantment allows you to ENCHANT your SEANCE at your will.
// come in with some SEANCE, and leave with some more! 
// handles swapping to and from ENCHANT -- our dex reward token.

contract Enchantment is ERC20("Enchantment", "ENCHANT"), Ownable, ReentrancyGuard {
    IERC20 public seance;
    
    bool isInitialized;
    
    event Enchant(address indexed user, uint amount);
    event Leave(address indexed user, uint share, uint amount);
    event NewSeance(IERC20 seance);

    // defines the SEANCE token contract.
    constructor(IERC20 _seance) { seance = _seance; }

    // initializes the contract to enable staking.
    function initialize() external onlyOwner {
        require(!isInitialized, 'already started');
        isInitialized = true;
    }

    // locks SEANCE, mints ENCHANT.
    function enchant(uint amount) external nonReentrant {
        require(isInitialized, 'staking has not yet begun');

        // gets the SEANCE locked in the contract.
        uint totalSeance = seance.balanceOf(address(this));
        // gets total ENCHANT in existence.
        uint totalShares = totalSupply();

        // if no ENCHANT exists, mint it 1:1 to the amount put in.
        if (totalShares == 0 || totalSeance == 0) {
            _mint(msg.sender, amount);
        }

        // calculate and mint the amount of ENCHANT the SEANCE is worth. 
        // the ratio will change overtime, as ENCHANT is burned/minted and SEANCE
        // deposited + gained from fees / withdrawn.
        
        else {
            uint mintable = amount * totalShares / totalSeance;
            _mint(msg.sender, mintable);
            }

        // transfers the SEANCE to the contract.
        seance.transferFrom(msg.sender, address(this), amount);

        emit Enchant(msg.sender, amount);

    }

    // leaves the ENCHANT. reclaims SEANCE.
    // unlocks staked + gained SEANCE | burns ENCHANT.
    function leave(uint share) external nonReentrant {
        // gets the amount of ENCHANT in existence.
        uint totalShares = totalSupply();

        // calculates the amount of SEANCE the ENCHANT is worth.
        uint amount = share * seance.balanceOf(address(this)) / totalShares;

        // burns the ENCHANT amount from the sender.
        _burn(msg.sender, share);

        // sends the SEANCE to the sender.
        seance.transfer(msg.sender, amount);

        emit Leave(msg.sender, share, amount);
    }

    function updateSeance(IERC20 _seance) public onlyOwner {
        seance = _seance;

        emit NewSeance(_seance);
    }
}
