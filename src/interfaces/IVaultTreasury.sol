// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDefaultErrors} from "./IDefaultErrors.sol";

interface IVaultTreasury is IDefaultErrors {
    function withdraw(address to, uint256 amount) external;
    function balance() external view returns (uint256);
    function tokenAddress() external view returns (address);
}
