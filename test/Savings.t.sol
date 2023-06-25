// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Savings.sol";
import "../src/Token.sol";
import "../src/Faucet.sol";

contract SavingTest is Test {
    event Deposit(address indexed depositor, address token, uint amount);
    event LowBalanceAlert(address indexed token, uint balance, uint timestamp);
    event Withdraw(address indexed depositor, address token, uint amount);
    event ClaimRewards(address indexed depositor, address token, uint amount);

    Savings public savings;
    Token public token;
    Faucet public faucet;

    uint constant _TOKEN_INITIAL_CONTRACT_SUPPLY = 1000000 * 10 ** 18;
    uint constant _TOKEN_INITIAL_USER_SUPPLY = 400 * 10 ** 18;

    uint constant _FAUCET_WITHDRAWABLE_AMOUNT = 100 * 10 ** 18;
    uint constant _FAUCET_COOLDOWN = 10;

    uint constant _ONE_YEAR = 60 * 60 * 24 * 365;

    uint16 constant _TOKEN_ANNUAL_RATE = 1000; // FORMAT 1000 = 10%

    address constant _AGENT_1 = address(1);
    address constant _AGENT_2 = address(2);
    address constant _AGENT_3 = address(3);
    address constant _USER_1 = address(4);
    address constant _USER_2 = address(5);

    address[] _initialAgents = [_AGENT_1, _AGENT_2];

    uint _requiredTokenBalanceUponAdding;
    uint _newTokenProposalDuration;

    function setUp() public {
        vm.prank(_AGENT_1);
        token = new Token(
            "Test Token",
            "TTT",
            _TOKEN_INITIAL_CONTRACT_SUPPLY + _TOKEN_INITIAL_USER_SUPPLY
        );
        vm.prank(_AGENT_1);
        savings = new Savings(_initialAgents);
        vm.prank(_AGENT_1);
        token.transfer(address(savings), _TOKEN_INITIAL_CONTRACT_SUPPLY);
        vm.prank(_AGENT_1);
        token.transfer(address(this), _TOKEN_INITIAL_USER_SUPPLY);

        /// @dev Adding a new token so that user can deposit and earn reward
        uint proposalId = savings.newTokenProposalsCount();
        vm.prank(_AGENT_1);
        savings.proposeNewToken(address(token), _TOKEN_ANNUAL_RATE);
        vm.prank(_AGENT_2);
        savings.voteNewToken(_AGENT_2, proposalId, true);
        skip(savings.NEW_TOKEN_PROPOSAL_DURATION());
        savings.executeNewTokenProposal(proposalId);
    }

    /// @dev Deposit

    /// @dev test user's first deposit and if states are updated correctly
    function testFirstDeposit() public {
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

    /// @dev test the rewards calculation on deposit (will be same on withdraw)
    function testRewardCalculation() public {
        uint depositInterval = _ONE_YEAR;

        uint depositAmount = _TOKEN_INITIAL_USER_SUPPLY;
        token.approve(address(savings), depositAmount);
        savings.deposit(address(token), depositAmount / 2);

        skip(depositInterval);

        savings.deposit(address(token), depositAmount / 2);

        Savings.BalanceState memory balanceState = savings.getBalanceState(
            address(this),
            address(token)
        );

        assertEq(
            balanceState.rewards,
            ((depositAmount / 2) * _TOKEN_ANNUAL_RATE) / 10000
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

    /// @dev Withdraw

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

    /// @dev Claim Rewards

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

    /// @dev test address' interest rate on deposit if they are in premium tier
    function testInterestRateWithPremiumTier() public {
        /// @dev Reverse engineering the amount address has to deposit to earn rewards that will
        /// @dev make the address premium tier
        uint depositAmountForPremiumTier = (savings
            .CLAIMED_REWARDS_CHECKPOINT() * 10000) / _TOKEN_ANNUAL_RATE;
        uint depositInterval = _ONE_YEAR;

        token.approve(address(savings), depositAmountForPremiumTier);
        savings.deposit(address(token), depositAmountForPremiumTier);

        skip(depositInterval);

        savings.withdraw(address(token), depositAmountForPremiumTier);

        Savings.BalanceState memory balanceStateBeforeClaiming = savings
            .getBalanceState(address(this), address(token));

        savings.claimRewards(
            address(token),
            balanceStateBeforeClaiming.rewards
        );

        uint depositAmountForTestingPremiumTier = 10 * 10 ** 18;

        token.approve(address(savings), depositAmountForTestingPremiumTier);
        savings.deposit(address(token), depositAmountForTestingPremiumTier);

        skip(depositInterval);

        savings.withdraw(address(token), depositAmountForTestingPremiumTier);

        Savings.BalanceState memory balanceState = savings.getBalanceState(
            address(this),
            address(token)
        );

        uint originalRewards = (depositAmountForTestingPremiumTier *
            _TOKEN_ANNUAL_RATE) / 10000;
        uint premiumTierRewards = (originalRewards *
            savings.PREMIUM_TIER_INTEREST_PERCENTAGE()) / 100;
        assertEq(balanceState.rewards, premiumTierRewards);
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
