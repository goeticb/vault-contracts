// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

import {IVaultTreasury} from "./interfaces/IVaultTreasury.sol";
import {IUsrRedemptionExtension} from "./interfaces/IUsrRedemptionExtension.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract UsrRedemptionExtension is
    IUsrRedemptionExtension,
    AccessControlDefaultAdminRules,
    Pausable
{
    constructor(address _admin) AccessControlDefaultAdminRules(1 days, _admin) {}
}
