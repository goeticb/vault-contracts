// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {ISimpleToken} from "./interfaces/ISimpleToken.sol";

contract VaultTokenShare is ISimpleToken, ERC20, ERC20Permit, AccessControlDefaultAdminRules {
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");

    mapping(bytes32 => bool) private mintIds;
    mapping(bytes32 => bool) private burnIds;

    modifier idempotentMint(bytes32 idempotencyKey) {
        if (mintIds[idempotencyKey]) {
            revert IdempotencyKeyAlreadyExist(idempotencyKey);
        }
        _;
        mintIds[idempotencyKey] = true;
    }

    modifier idempotentBurn(bytes32 idempotencyKey) {
        if (burnIds[idempotencyKey]) {
            revert IdempotencyKeyAlreadyExist(idempotencyKey);
        }
        _;
        burnIds[idempotencyKey] = true;
    }

    constructor(string memory _name, string memory _symbol, address _admin)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        AccessControlDefaultAdminRules(1 days, _admin)
    {}

    function mint(address _account, uint256 _amount) external onlyRole(SERVICE_ROLE) {
        _mint(_account, _amount);
    }

    function mint(bytes32 _idempotencyKey, address _account, uint256 _amount)
        external
        onlyRole(SERVICE_ROLE)
        idempotentMint(_idempotencyKey)
    {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyRole(SERVICE_ROLE) {
        _burn(_account, _amount);
    }

    function burn(bytes32 _idempotencyKey, address _account, uint256 _amount)
        external
        onlyRole(SERVICE_ROLE)
        idempotentBurn(_idempotencyKey)
    {
        _burn(_account, _amount);
    }
}
