// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/Savings.sol";
import "../../src/Token.sol";
import "../../src/Faucet.sol";

contract SavingsTest is Test {
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

    /// @dev test the rewards calculation on deposit (will be same on withdraw)
    /// @dev I have this test case here because its general
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

    /// @dev test address' interest rate on deposit if they are in premium tier
    /// @dev I have this test case here because it involves everything
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
}
