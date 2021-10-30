// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IPair.sol";
import "../interfaces/IEnchant.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ISummoner.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoulAura is Ownable {

    ISummoner summoner = ISummoner(0xce6ccbB1EdAD497B4d53d829DF491aF70065AB5B);
    ISoulSwapPair pair = ISoulSwapPair(0xa2527Af9DABf3E3B4979d7E0493b5e2C6e63dC57); // SOUL-FTM

    IEnchant enchant = IEnchant(0x6a1a8368D607c7a808F7BbA4F7aEd1D9EbDE147a);
    IERC20 soul = IERC20(0xe2fb177009FF39F52C0134E8007FA0e4BaAcBd07);
    IERC20 seance = IERC20(0x124B06C5ce47De7A6e9EFDA71a946717130079E6);

    function name() public pure returns (string memory) { return "SoulAura"; }
    function symbol() public pure returns (string memory) { return "AURA"; }
    function decimals() public pure returns (uint8) { return 18; }


    // transfers ownership to the DAO.
    constructor() { transferOwnership(0x1C63C726926197BD3CB75d86bCFB1DaeBcD87250); }

    // gets the total voting power = twice the reserves in the LP + enchanted seance.
    function totalSupply() public view returns (uint) {
    
        // SOUL reserves in the SOUL-FTM LP contract.
        (, uint lp_totalSoul, ) = pair.getReserves();

        // total SEANCE staked in ENCHANT.
        uint enchant_totalSeance = seance.balanceOf(address(enchant));

        return lp_totalSoul * 2 + enchant_totalSeance;
    }

    function balanceOf(address member) public view returns (uint) {

        //////////////////////////
        //     LP BALANCE       //
        //////////////////////////

        uint lp_total = pair.totalSupply();
        uint lp_totalSoul = soul.balanceOf(address(pair));

        // wallet balance.
        uint lp_walletBalance = pair.balanceOf(member);

        // staked balance
        (uint lp_stakedBalance, ) = summoner.userInfo(1, member);
        
        // lp balance [user]
        uint lp_balance = lp_walletBalance + lp_stakedBalance;

        // LP voting power is 2X the members' SOUL share in the pool.
        uint lp_power = lp_totalSoul * lp_balance / lp_total * 2;

        //////////////////////////
        //    ENCHANT BALANCE   //
        //////////////////////////

        uint enchant_total = enchant.totalSupply();
        uint enchant_balance = enchant.balanceOf(member);
        uint enchant_totalSeance = seance.balanceOf(address(enchant));

        // enchanted voting power is the members' enchanted SEANCE share.
        uint enchanted_power = enchant_totalSeance * enchant_balance / enchant_total;

        //////////////////////////
        //      SOUL POWER      //
        //////////////////////////
        
        // soul power is the members' SOUL balance.
        uint soul_power = soul.balanceOf(member);

        return lp_power + enchanted_power + soul_power;
    }

    // gets: member's pooled power
    function pooledPower(address member) public view returns (uint raw, uint formatted) {
        uint lp_total = pair.totalSupply();
        uint lp_totalSoul = soul.balanceOf(address(pair));

        // wallet balance.
        uint lp_walletBalance = pair.balanceOf(member);

        // staked balance
        (uint lp_stakedBalance, ) = summoner.userInfo(1, member);
        
        // lp balance [user]
        uint lp_balance = lp_walletBalance + lp_stakedBalance;

        // LP voting power is 2X the members' SOUL share in the lp pool.
        uint lp_power = lp_totalSoul * lp_balance / lp_total * 2;

        return (lp_power, fromWei(lp_power));

    }

    // gets: member's enchanted power
    function enchantedPower(address member) public view returns (uint raw, uint formatted) {
        uint enchant_total = enchant.totalSupply();
        uint enchant_balance = enchant.balanceOf(member);
        uint enchant_totalSeance = seance.balanceOf(address(enchant));

        // enchanted voting power is the members' enchanted SEANCE share.
        uint enchanted_power = enchant_totalSeance * enchant_balance / enchant_total;

        return (enchanted_power, fromWei(enchanted_power));
    }

    // gets: member's SOUL power
    function soulPower(address member) public view returns (uint raw, uint formatted) {
        // soul power is the members' SOUL balance.
        uint soul_power = soul.balanceOf(member);

        return (soul_power, fromWei(soul_power));
    }

    // gets: sender's pooled power
    function pooledPower() public view returns (uint raw, uint formatted) {
        uint lp_total = pair.totalSupply();
        uint lp_totalSoul = soul.balanceOf(address(pair));

        // wallet balance.
        uint lp_walletBalance = pair.balanceOf(msg.sender);

        // staked balance
        (uint lp_stakedBalance, ) = summoner.userInfo(1, msg.sender);
        
        // lp balance [user]
        uint lp_balance = lp_walletBalance + lp_stakedBalance;

        // LP voting power is 2X the sender's SOUL share in the lp pool.
        uint lp_power = lp_totalSoul * lp_balance / lp_total * 2;

        return (lp_power, fromWei(lp_power));

    }
    
    // gets: sender's enchanted power
    function enchantedPower() public view returns (uint raw, uint formatted) {
        uint enchant_total = enchant.totalSupply();
        uint enchant_balance = enchant.balanceOf(msg.sender);
        uint enchant_totalSeance = seance.balanceOf(address(enchant));

        // enchanted voting power is the sender's enchanted SEANCE share.
        uint enchanted_power = enchant_totalSeance * enchant_balance / enchant_total;

        return (enchanted_power, fromWei(enchanted_power));
    }

    // gets: sender's SOUL power
    function soulPower() public view returns (uint raw, uint formatted) {
        // soul power is the sender's SOUL balance.
        uint soul_power = soul.balanceOf(msg.sender);

        return (soul_power, fromWei(soul_power));
    }

    // disables ERC20 functionality.
    function allowance(address, address) public pure returns (uint) { return 0; }
    function transfer(address, uint) public pure returns (bool) { return false; }
    function approve(address, uint) public pure returns (bool) { return false; }
    function transferFrom(address, address, uint) public pure returns (bool) { return false; }

    // conversion helper functions
    function toWei(uint intNum) public pure returns (uint bigInt) { return intNum * 10**18; }
    function fromWei(uint bigInt) public pure returns (uint intNum) { return bigInt / 10**18; }
}
