// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract SoulSwapVoterProxy {
    // SEANCE
    address public votes; // constant votes = 0x744342261860f01826922ea973ecfecd727a25e0;

    function decimals() external pure returns (uint8) {
        return uint8(18);
    }

    function name() external pure returns (string memory) {
        return 'SEANCEVOTE';
    }

    function symbol() external pure returns (string memory) {
        return 'SEANCE';
    }

    function totalSupply() external view returns (uint256) {
        return IERC20(votes).totalSupply();
    }

    function balanceOf(address _voter) external view returns (uint256) {
        return IERC20(votes).balanceOf(_voter);
    }

    constructor() {}
}