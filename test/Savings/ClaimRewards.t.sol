// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Savings.t.sol";

contract ClaimRewardsTest is SavingsTest {
    function testClaimRewards() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        uint waitTime = _ONE_YEAR;

        skip(waitTime);

        savings.withdraw(address(token), depositAmount);

        Savings.BalanceState memory balanceStateBeforeClaiming = savings
            .getBalanceState(address(this), address(token));

        savings.claimRewards(
            address(token),
            balanceStateBeforeClaiming.rewards
        );

        Savings.BalanceState memory balanceStateAfterClaiming = savings
            .getBalanceState(address(this), address(token));

        assertEq(
            balanceStateAfterClaiming.totalRewardsClaimed,
            balanceStateBeforeClaiming.rewards
        );
        assertEq(
            token.balanceOf(address(this)),
            depositAmount + balanceStateBeforeClaiming.rewards
        );
    }

    /// @dev test if claimRewards will fire an event
    function testClaimRewardsEvent() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);
        skip(_ONE_YEAR);
        savings.withdraw(address(token), depositAmount);
        Savings.BalanceState memory balanceState = savings.getBalanceState(
            address(this),
            address(token)
        );

        vm.expectEmit(true, false, false, true);
        emit ClaimRewards(address(this), address(token), balanceState.rewards);
        savings.claimRewards(address(token), balanceState.rewards);
    }

    /// @dev test if it reverts if address tries to claim 0 rewards
    function testClaimRewardsWithZeroAmount() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);
        skip(_ONE_YEAR);
        savings.withdraw(address(token), depositAmount);

        vm.expectRevert();
        savings.claimRewards(address(token), 0);
    }

    /// @dev test if it reverts if address tries to claim more rewards than available
    function testClaimMoreRewardsThanAvailable() public {
        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount);

        skip(10);

        savings.withdraw(address(token), depositAmount);

        vm.expectRevert();
        savings.claimRewards(address(token), depositAmount);
    }

    /// @dev tests if the contract will fire the event on low balance
    function testLowBalanceAlertEvent() public {
        /// @dev Reverse engineering the amount we need to deposit that will trigger the low balance event
        /// @dev when withdraw and claim rewards after 1 year
        uint rewardsToGiveToTriggerEvent = _TOKEN_INITIAL_CONTRACT_SUPPLY -
            savings.BALANCE_ALERT_THRESHOLD();

        /// @dev Instead of depositing HUGE amount to drain the contract, I'll just send the tokens from contract to some address
        /// @dev So that the dposit amount will be minimum to trigger the low balance alert
        /// @dev Here you will see that giving out only 10 tokens will now trigger the alert.
        uint delta = 10;
        uint wastedAmount = rewardsToGiveToTriggerEvent - delta;
        vm.prank(address(savings));
        token.transfer(address(123), wastedAmount);

        /// @dev Reverse engineering how many tokens to deposit for a year to make contract pay the delta (10) amount and trigger the event
        uint amountToDeposit = (delta * 10000) / _TOKEN_ANNUAL_RATE;

        token.approve(address(savings), amountToDeposit);
        savings.deposit(address(token), amountToDeposit);

        skip(_ONE_YEAR);

        savings.withdraw(address(token), amountToDeposit);

        uint rewardsToClaim = (amountToDeposit * _TOKEN_ANNUAL_RATE) / 10000;

        vm.expectEmit(true, false, false, true);
        emit LowBalanceAlert(
            address(token),
            token.balanceOf(address(savings)) - rewardsToClaim,
            block.timestamp
        );
        savings.claimRewards(address(token), rewardsToClaim);
    }
}
