// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import './libraries/ERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// aura is the neatest bound around. come in with some soul, and leave with some more! 
// handles swapping to and from AURA -- our dex reward token.

contract SoulBound is ERC20("SoulBound", "AURA"), Ownable, ReentrancyGuard {
    IERC20 public soul;
    IERC20 public seance;
    bool isInitialized; // stores whether contract has been initialized

    // the soul token contract
    function initialize(IERC20 _soul, IERC20 _seance) external onlyOwner {
        require(!isInitialized, 'already started');
        soul = _soul;
        seance = _seance;

        isInitialized = true;
    }

    function totalSeance() public view returns (uint) {
        return seance.balanceOf(address(this));
    }

    function totalSoul() public view returns (uint) {
        return soul.balanceOf(address(this));
    }

    // (total) soul + seance owed to stakers
    function totalPayable() public view returns (uint) {
        uint soulTotal = totalSoul();
        uint seanceTotal = totalSeance();

        return seanceTotal + soulTotal;
    }

    function mintableAura(uint _seanceStakable) internal view returns (uint) {
        uint soulAura; // initiates soul aura

        totalPayable() == 0 
            ? soulAura = 1 // sets an aura power of 1
            : soulAura = totalSupply() / totalPayable(); // sets weight for aura power

        return _seanceStakable * soulAura; // sets aura to mint
    }

    // locks soul, mints aura at aura rate
    function enter(uint seanceStakable) external nonReentrant {
        require(isInitialized, 'staking has not yet begun');
        uint auraMintable = mintableAura(seanceStakable); // total aura to mine to sender
        
        seance.transferFrom(msg.sender, address(this), seanceStakable); // transfers seance from sender
        _mint(msg.sender, auraMintable); // mints aura to sender
    }

    // leaves the soulAura. reclaims soul.
    // unlocks soul rewards + staked seance | burns bounded aura
    function leave(uint auraShare) external nonReentrant {

        // exchange rates
        uint soulRate = totalSoul() / totalSupply(); // soul per aura (exchange rate)
        uint seanceRate = totalSeance() / totalSupply(); // seance per aura (exchange rate)

        // payable component shares
        uint soulShare = auraShare * soulRate; // exchanges aura for soul (at soul rate)
        uint seanceShare = auraShare * seanceRate; // exchanges aura for seance (at soul rate)

        _burn(msg.sender, auraShare);
        soul.transfer(msg.sender, soulShare);
        seance.transfer(msg.sender, seanceShare);
    }



}
