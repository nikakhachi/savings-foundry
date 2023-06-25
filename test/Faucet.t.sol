// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Token.sol";
import "../src/Faucet.sol";

contract FaucetTest is Test {
    uint constant INITIAL_SUPPLY = 1000 * 10 ** 18;
    uint constant WITHDRAWABLE_AMOUNT = 10 * 10 ** 18;
    uint constant COOLDOWN = 10;

    event Withdraw(address indexed user, uint timestamp); /// @dev redeclaring the Faucet's event

    Token public token;
    Faucet public faucet;

    function setUp() public {
        token = new Token("Test Token", "TTK", INITIAL_SUPPLY);
        faucet = new Faucet(address(token), WITHDRAWABLE_AMOUNT, COOLDOWN);
        token.transfer(address(faucet), INITIAL_SUPPLY);
    }

    function testEvent() public {
        vm.expectEmit(true, false, true, false);
        emit Withdraw(address(this), block.timestamp);
        faucet.withdraw();
    }

    function testWithdraw() public {
        assertEq(token.balanceOf(address(this)), 0);
        faucet.withdraw();
        assertEq(token.balanceOf(address(this)), WITHDRAWABLE_AMOUNT);
        assertEq(
            token.balanceOf(address(faucet)),
            INITIAL_SUPPLY - WITHDRAWABLE_AMOUNT
        );
    }

    function testWithdrawAfterCooldown() public {
        faucet.withdraw();
        skip(COOLDOWN);
        faucet.withdraw();
    }

    function testCooldown() public {
        faucet.withdraw();
        vm.expectRevert(Faucet.TooManyRequests.selector);
        faucet.withdraw();
    }

    function testOutOfFunds() public {
        for (uint i = 0; i < INITIAL_SUPPLY / WITHDRAWABLE_AMOUNT; i++) {
            faucet.withdraw();
            skip(COOLDOWN);
        }
        vm.expectRevert(Faucet.InsufficientFunds.selector);
        faucet.withdraw();
    }
}