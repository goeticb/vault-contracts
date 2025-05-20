// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IVaultTreasury} from "./interfaces/IVaultTreasury.sol";

contract VaultTreasury is IVaultTreasury, AccessControlDefaultAdminRules {
    using SafeERC20 for IERC20;

    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");

    address public immutable tokenAddress;

    constructor(address _tokenAddress, address _admin) AccessControlDefaultAdminRules(1 days, _admin) {
        tokenAddress = _assertNonZero(_tokenAddress);
        _grantRole(SERVICE_ROLE, _admin);
    }

    function withdraw(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Zero address");
        IERC20(tokenAddress).safeTransfer(to, amount);
    }

    function balance() external view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function _assertNonZero(address _address) internal pure returns (address nonZeroAddress) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }
}
