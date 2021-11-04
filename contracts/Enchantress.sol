// SPDX-License-Identifier: MIT

// P1 - P3: OK
pragma solidity >=0.6.12;
import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";

import "./soulswap/interfaces/ISoulSwapERC20.sol";
import "./soulswap/interfaces/ISoulSwapPair.sol";
import "./soulswap/interfaces/ISoulSwapFactory.sol";

import "./libraries/BoringOwnable.sol";

// P1 - P3: OK
pragma solidity >=0.6.12;

// Enchantress is the Summoner's left hand and kinda a bruja. She can enchant from pretty much anything!
// This contract handles "conjuring up" rewards for ENCHANT holders by trading tokens collected from fees for Enchant.

// T1 - T4: OK
contract Enchantress is BoringOwnable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // V1 - V5: OK
    ISoulSwapFactory public immutable factory;
    //0x1120e150dA9def6Fe930f4fEDeD18ef57c0CA7eF
    // V1 - V5: OK
    address public immutable enchantment;
    //0x6a1a8368d607c7a808f7bba4f7aed1d9ebde147a
    // V1 - V5: OK
    address private immutable seance;
    //0x124B06C5ce47De7A6e9EFDA71a946717130079E6
    // V1 - V5: OK
    address private immutable wftm;
    //0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83

    // V1 - V5: OK
    mapping(address => address) internal _bridges;

    // E1: OK
    event LogBridgeSet(address indexed token, address indexed bridge);
    // E1: OK
    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amountJOE
    );

    constructor(
        address _factory,
        address _enchantment,
        address _seance,
        address _wftm
    ) {
        factory = ISoulSwapFactory(_factory);
        enchantment = _enchantment;
        seance = _seance;
        wftm = _wftm;
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = wftm;
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function setBridge(address token, address bridge) external onlyOwner {
        // Checks
        require(token != seance && token != wftm && token != bridge, "Enchantress: Invalid bridge");

        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    // M1 - M5: OK
    // C1 - C24: OK
    // C6: It's not a fool proof solution, but it prevents flash loans, so here it's ok to use tx.origin
    modifier onlyEOA() {
        // Try to make flash-loan exploit harder to do by only allowing externally owned addresses.
        require(msg.sender == tx.origin, "Enchantress: must use EOA");
        _;
    }

    // F1 - F10: OK
    // F3: _convert is separate to save gas by only checking the 'onlyEOA' modifier once in case of convertMultiple
    // F6: There is an exploit to add lots of SEANCE to the enchantment, run convert, then remove the SEANCE again.
    // As the size of the Enchantment has grown, this requires large amounts of funds and isn't super profitable anymore
    // The onlyEOA modifier prevents this being done with a flash loan.
    // C1 - C24: OK
    function convert(address token0, address token1) external onlyEOA() {
        _convert(token0, token1);
    }

    // F1 - F10: OK, see convert
    // C1 - C24: OK
    // C3: Loop is under control of the caller
    function convertMultiple(address[] calldata token0, address[] calldata token1) external onlyEOA() {
        // TODO: This can be optimized a fair bit, but this is safer and simpler for now
        uint256 len = token0.length;
        for (uint256 i = 0; i < len; i++) {
            _convert(token0[i], token1[i]);
        }
    }

    // F1 - F10: OK
    // C1- C24: OK
    function _convert(address token0, address token1) internal {
        // Interactions
        // S1 - S4: OK
        ISoulSwapPair pair = ISoulSwapPair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "Enchantress: Invalid pair");
        // balanceOf: S1 - S4: OK
        // transfer: X1 - X5: OK
        IERC20(address(pair)).safeTransfer(address(pair), pair.balanceOf(address(this)));
        // X1 - X5: OK
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        if (token0 != pair.token0()) {
            (amount0, amount1) = (amount1, amount0);
        }
        emit LogConvert(msg.sender, token0, token1, amount0, amount1, _convertStep(token0, token1, amount0, amount1));
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, _swap, _toSEANCE, _convertStep: X1 - X5: OK
    function _convertStep(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 seanceOut) {
        // Interactions
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == seance) {
                IERC20(seance).safeTransfer(enchantment, amount);
                seanceOut = amount;
            } else if (token0 == wftm) {
                seanceOut = _toSEANCE(wftm, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                seanceOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == seance) {
            // eg. SEANCE - FTM
            IERC20(seance).safeTransfer(enchantment, amount0);
            seanceOut = _toSEANCE(token1, amount1).add(amount0);
        } else if (token1 == seance) {
            // eg. USDT - SEANCE
            IERC20(seance).safeTransfer(enchantment, amount1);
            seanceOut = _toSEANCE(token0, amount0).add(amount1);
        } else if (token0 == wftm) {
            // eg. FTM - USDC
            seanceOut = _toSEANCE(wftm, _swap(token1, wftm, amount1, address(this)).add(amount0));
        } else if (token1 == wftm) {
            // eg. USDT - FTM
            seanceOut = _toSEANCE(wftm, _swap(token0, wftm, amount0, address(this)).add(amount1));
        } else {
            // eg. MIC - USDT
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) {
                // eg. MIC - USDT - and bridgeFor(MIC) = USDT
                seanceOut = _convertStep(bridge0, token1, _swap(token0, bridge0, amount0, address(this)), amount1);
            } else if (bridge1 == token0) {
                // eg. WBTC - DSD - and bridgeFor(DSD) = WBTC
                seanceOut = _convertStep(token0, bridge1, amount0, _swap(token1, bridge1, amount1, address(this)));
            } else {
                seanceOut = _convertStep(
                    bridge0,
                    bridge1, // eg. USDT - DSD - and bridgeFor(DSD) = WBTC
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, swap: X1 - X5: OK
    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        // Checks
        // X1 - X5: OK
        ISoulSwapPair pair = ISoulSwapPair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "Enchantress: Cannot convert");

        // Interactions
        // X1 - X5: OK
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut = amountIn.mul(997).mul(reserve1) / reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            // TODO: Add maximum slippage?
        } else {
            amountOut = amountIn.mul(997).mul(reserve0) / reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            // TODO: Add maximum slippage?
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function _toSEANCE(address token, uint256 amountIn) internal returns (uint256 amountOut) {
        // X1 - X5: OK
        amountOut = _swap(token, seance, amountIn, enchantment);
    }
}
