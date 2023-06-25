// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Savings.t.sol";

/// @dev This contract contains test cases specific to the deposit() function of Savings contract
contract DepositTest is SavingsTest {
    /// @dev test user's deposit and if states are updated correctly
    function testDeposit() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);
        Savings.BalanceState memory balanceState = savings.getBalanceState(
            address(this),
            address(token)
        );
        assertEq(balanceState.balance, depositAmount);
        assertEq(balanceState.lastBalanceUpdateTimestamp, block.timestamp);
        assertEq(balanceState.rewards, 0);
        assertEq(balanceState.totalRewardsClaimed, 0);
        assertEq(
            token.balanceOf(address(savings)),
            _TOKEN_INITIAL_CONTRACT_SUPPLY + depositAmount
        );
        assertEq(
            token.balanceOf(address(this)),
            _TOKEN_INITIAL_USER_SUPPLY - depositAmount
        );
    }

    /// @dev test if deposit will fire event
    function testDepositEvent() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), address(token), depositAmount);
        savings.deposit(address(token), depositAmount);
    }

    /// @dev test if it reverts if address tries to deposit with 0 value;
    function testDepositWithZeroAmount() public {
        vm.expectRevert();
        savings.deposit(address(token), 0);
    }
}
