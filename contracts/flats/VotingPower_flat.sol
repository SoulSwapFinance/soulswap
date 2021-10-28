// SPDX-License-Identifier: GPL-3.0

// File: contracts/interfaces/IPair.sol
pragma solidity >=0.5.0;

interface ISoulSwapPair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);
    function token1() external view returns (address);
    
    function getReserves() external view returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out, 
        uint256 amount1Out, 
        address to, 
        bytes calldata data
    ) external;

    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File: contracts/interfaces/IBound.sol
pragma solidity ^0.8.4;

interface IBound {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
}

// File: contracts/interfaces/IERC20.sol
pragma solidity ^0.8.4;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// File: contracts/interfaces/ISummoner.sol
pragma solidity ^0.8.7;

interface ISummoner {
    function userInfo(uint pid, address owner) external view returns (uint, uint);
}

// File: contracts/governance/VotingPower.sol
pragma solidity ^0.8.7;

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
        
        bound = IBound(0xFB582442c4D25f30a561a43b266deF94662dd556);
        
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
