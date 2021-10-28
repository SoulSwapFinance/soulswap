// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IPair.sol";
import "../interfaces/IBound.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ISummoner.sol";

contract SoulAura {

    address DAO;
    ISoulSwapPair soulFtm;
    IBound bound;
    IERC20 soul;
    IERC20 seance;
    ISummoner summoner;
    uint pid; // PID: SOUL-FTM LP

    function name() public pure returns (string memory) { return "SoulAura"; }
    function symbol() public pure returns (string memory) { return "AURA"; }
    function decimals() public pure returns (uint8) { return 18; }

    constructor() {
        pid = 1;
        summoner = ISummoner(0xce6ccbB1EdAD497B4d53d829DF491aF70065AB5B);
        DAO = 0x1C63C726926197BD3CB75d86bCFB1DaeBcD87250;
        
        bound = IBound(0x409Ca67669DC604Eb36dba68d11de1a24F1EE5f9);
        
        soulFtm = ISoulSwapPair(0xa2527Af9DABf3E3B4979d7E0493b5e2C6e63dC57);
        
        seance = IERC20(0x124B06C5ce47De7A6e9EFDA71a946717130079E6);
        soul = IERC20(0xe2fb177009FF39F52C0134E8007FA0e4BaAcBd07);
    }

    function totalSupply() public view returns (uint) {
        (uint lp_totalSoul, , ) = soulFtm.getReserves();
        uint seance_totalSoul = soul.balanceOf(address(bound));

        return lp_totalSoul * 2 + seance_totalSoul;
    }

    function balanceOf(address owner) public view returns (uint) {
        //////////////////////////
        //    LP BALANCE(S)     //
        //////////////////////////
        uint lp_totalSoul = soul.balanceOf(address(soulFtm));
        uint lp_total = soulFtm.totalSupply();
        uint lp_balance = soulFtm.balanceOf(owner);

        // ADD: Staked Soul Balance
        (uint lp_stakedBalance, ) = summoner.userInfo(pid, owner);
        lp_balance = lp_balance + lp_stakedBalance;

        // LP POWER = 2X the users SOUL share in the pool.
        uint lp_power = lp_totalSoul * lp_balance / lp_total * 2;

        //////////////////////////
        //    SEANCE BALANCE    //
        //////////////////////////

        uint seance_balance = seance.balanceOf(owner);
        uint seance_total = seance.totalSupply();
        uint bound_totalSoul = soul.balanceOf(address(bound));

        // SEANCE voting power is the users SOUL share in the bound.
        uint soul_bound = bound_totalSoul * seance_balance / seance_total;

        //////////////////////////
        //      SOUL BALANCE    //
        //////////////////////////

        uint soul_balance = soul.balanceOf(owner);
        return lp_power + soul_bound + soul_balance;
    }

    function updateConstants(
        address _DAO,
        ISoulSwapPair _soulFtm, 
        uint _pid, 
        ISummoner _summoner,
        IERC20 _soul, 
        IERC20 _seance,
        IBound _bound
        ) public {
            require(msg.sender == DAO, 'only DAO');

            DAO = _DAO;
            summoner = _summoner;
            pid = _pid;

            bound = _bound;
            
            soulFtm = _soulFtm;
            soul = _soul;
            seance = _seance;
        }

    function allowance(address, address) public pure returns (uint) { return 0; }
    function transfer(address, uint) public pure returns (bool) { return false; }
    function approve(address, uint) public pure returns (bool) { return false; }
    function transferFrom(address, address, uint) public pure returns (bool) { return false; }

    function toWei(uint intNum) public pure returns (uint bigInt) { return intNum * 10**18; }
    function fromWei(uint bigInt) public pure returns (uint intNum) { return bigInt / 10**18; }
}