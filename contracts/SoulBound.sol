// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import './libraries/ERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// SoulBound is the neatest bound around. come in with some soul, and leave with some more! 
// handles swapping to and from BOUND -- our dex reward token.

contract SoulBound is ERC20("SoulBound", "BOUND"), Ownable, ReentrancyGuard {
    IERC20 public soul;
    IERC20 public seance;
    bool isInitialized; // stores whether contract has been initialized
    event NewConstants(IERC20 _soul, IERC20 _seance);

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

    function mintableBound(uint _seanceStakable) internal view returns (uint) {
        uint soulBound; // initiates soul bound

        totalPayable() == 0 
            ? soulBound = 1 // sets an bound power of 1
            : soulBound = totalSupply() / totalPayable(); // sets weight for bound power

        return _seanceStakable * soulBound; // sets bound to mint
    }

    // locks soul, mints bound at bound rate
    function enter(uint seanceStakable) external nonReentrant {
        require(isInitialized, 'staking has not yet begun');
        uint boundMintable = mintableBound(seanceStakable); // total bound to mine to sender
        
        seance.transferFrom(msg.sender, address(this), seanceStakable); // transfers seance from sender
        _mint(msg.sender, boundMintable); // mints bound to sender
    }

    // leaves the bound. reclaims soul.
    // unlocks soul rewards + staked seance | burns bound
    function leave(uint boundShare) external nonReentrant {

        // exchange rates
        uint soulRate = totalSoul() / totalSupply(); // soul per bound (exchange rate)
        uint seanceRate = totalSeance() / totalSupply(); // seance per bound (exchange rate)

        // payable component shares
        uint soulShare = boundShare * soulRate; // exchanges bound for soul (at soul rate)
        uint seanceShare = boundShare * seanceRate; // exchanges bound for seance (at soul rate)

        _burn(msg.sender, boundShare);
        soul.transfer(msg.sender, soulShare);
        seance.transfer(msg.sender, seanceShare);
    }

    function updateConstants(IERC20 _soul, IERC20 _seance) public onlyOwner {
        soul = _soul;
        seance = _seance;

        emit NewConstants(_soul, _seance);
    }

}
