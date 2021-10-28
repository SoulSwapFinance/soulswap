// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

interface ISummoner {
    function userInfo(uint pid, address owner) external view returns (uint, uint);
}
