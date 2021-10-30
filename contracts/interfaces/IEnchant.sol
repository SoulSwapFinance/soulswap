// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IEnchant {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
}