// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {VaultTreasury} from "../src/VaultTreasury.sol";
import {VaultTokenShare} from "../src/VaultTokenShare.sol";
import {UsrExternalRequestsManager} from "../src/UsrExternalRequestsManager.sol";

contract CounterTest is Test {
    Counter public counter;
    VaultTokenShare public valutTokenShare;
    VaultTreasury public vaultTrasury;
    UsrExternalRequestsManager public usrExternalRequestsManager;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
        valutTokenShare = new VaultTokenShare("Test", "TST", address(this));
        vaultTrasury = new VaultTreasury(address(uint160(bytes20("Mocked USDT Address"))), address(this));
        usrExternalRequestsManager = new UsrExternalRequestsManager(
            address(this),
            address(valutTokenShare),
            address(uint160(bytes20("Mocked USDT Address"))),
            18,
            address(vaultTrasury),
            address(1)
        );
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
        vaultTrasury.hasRole(keccak256("SERVICE_ROLE"), address(this));
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);

        assertEq(counter.number(), x);
    }
}
