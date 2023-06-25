// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Token.sol";
import "../src/Faucet.sol";

contract FaucetTest is Test {
    uint constant _INITIAL_SUPPLY = 1000 * 10 ** 18;
    uint constant _WITHDRAWABLE_AMOUNT = 10 * 10 ** 18;
    uint constant _COOLDOWN = 10;

    event Withdraw(address indexed user, uint timestamp); /// @dev redeclaring the Faucet's event

    Token public token;
    Faucet public faucet;

    function setUp() public {
        token = new Token("Test Token", "TTK", _INITIAL_SUPPLY);
        faucet = new Faucet(address(token), _WITHDRAWABLE_AMOUNT, _COOLDOWN);
        token.transfer(address(faucet), _INITIAL_SUPPLY);
    }

    /// @dev test if the event is fired on withdrawal
    function testEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Withdraw(address(this), block.timestamp);
        faucet.withdraw();
    }

    /// @dev test the withdrawal function
    function testWithdraw() public {
        assertEq(token.balanceOf(address(this)), 0);
        faucet.withdraw();
        assertEq(token.balanceOf(address(this)), _WITHDRAWABLE_AMOUNT);
        assertEq(
            token.balanceOf(address(faucet)),
            _INITIAL_SUPPLY - _WITHDRAWABLE_AMOUNT
        );
    }

    /// @dev test the withdrawal function after cooldown is off
    function testWithdrawAfterCooldown() public {
        faucet.withdraw();
        skip(_COOLDOWN);
        faucet.withdraw();
    }

    /// @dev test if it reverts if trying to withdraw twice within the cooldown
    function testCooldown() public {
        faucet.withdraw();
        vm.expectRevert(Faucet.TooManyRequests.selector);
        faucet.withdraw();
    }

    /// @dev test if it reverts when trying to withdraw funds when contract has insufficient balance
    function testOutOfFunds() public {
        for (uint i = 0; i < _INITIAL_SUPPLY / _WITHDRAWABLE_AMOUNT; i++) {
            faucet.withdraw();
            skip(_COOLDOWN);
        }
        vm.expectRevert(Faucet.InsufficientFunds.selector);
        faucet.withdraw();
    }
}
