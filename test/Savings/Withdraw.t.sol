// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Savings.t.sol";

/// @dev This contract contains test cases specific to the withdraw() function of Savings contract
contract WithdrawTest is SavingsTest {
    /// @dev test withdraw function
    function testWithdraw() public {
        uint startingTimestamp = block.timestamp;

        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        uint waitTime = _ONE_YEAR;

        skip(waitTime);

        savings.withdraw(address(token), depositAmount);

        Savings.BalanceState memory balanceState = savings.getBalanceState(
            address(this),
            address(token)
        );

        uint supposedRewards = (depositAmount * _TOKEN_ANNUAL_RATE) / 10000;

        assertEq(balanceState.balance, 0);
        assertEq(
            balanceState.lastBalanceUpdateTimestamp,
            startingTimestamp + waitTime
        );
        assertEq(balanceState.rewards, supposedRewards);
        assertEq(balanceState.totalRewardsClaimed, 0);
        assertEq(
            token.balanceOf(address(savings)),
            _TOKEN_INITIAL_CONTRACT_SUPPLY
        );
        assertEq(token.balanceOf(address(this)), _TOKEN_INITIAL_USER_SUPPLY);
    }

    /// @dev test if withdraw will fire an event
    function testWithdrawEvent() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        skip(10);

        vm.expectEmit(true, false, false, true);
        emit Withdraw(address(this), address(token), depositAmount);
        savings.withdraw(address(token), depositAmount);
    }

    /// @dev test if it reverts if address tries to withdraw 0 amount
    function testWithdrawWithZeroAmount() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        skip(10);

        vm.expectRevert();
        savings.withdraw(address(token), 0);
    }

    /// @dev test if it reverts if address tries to withdraw more amount that its deposited
    function testWithdrawMoreDeposit() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        skip(10);

        vm.expectRevert();
        savings.withdraw(address(token), depositAmount * 2);
    }
}
