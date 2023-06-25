// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.sol";

/// @title Savings
/// @author Nika Khachiashvili
/// @dev The contract is the main contract that will be deployed and contains the external functions for everyone
/// @dev For depositing, withdrawing and getting the rewards. It also inherits SavingsAgent that has supported
/// @dev tokens data and the voting system implemented.
/// @dev TODO Possible feature additions are mentioned in the comments of deposit() and earnRewards()
contract Savings is SavingsAgent {
    event Deposit(address indexed depositor, address token, uint amount);
    event LowBalanceAlert(address indexed token, uint balance, uint timestamp);

    /// @dev If the balance hits this number, LowBalanceAlert will be evoked.
    /// @dev TODO Can be implemented that it's unique for each token and also modifible by voting
    uint public constant balanceAlertThreshold = 3000 * 10 ** 18;

    struct BalanceState {
        uint balance; /// @dev amount of token that user has deposited and is "saving"
        /// @dev `rewards` ref: amount of token that user gets as a reward based on the balance, gets updated when user
        /// @dev updates the balance property with deposit() or withdraw()
        uint rewards;
        uint lastBalanceUpdateTimestamp; /// @dev timestamp of the last updated balance
        uint totalRewardsClaimed; /// @dev total rewards that the address has claimed of specific token
    }

    /// @dev Balance states for each token for each user
    mapping(address => mapping(address => BalanceState))
        public userBalanceStates;

    /// @dev if the address collects this amount or more tokens as rewards, they will be able
    /// @dev to recieve the 120% (premiumTierInterestPercentage) of the original rate on that specific token
    /// @dev TODO This implementation isn't perfect, because totalClaimedRewardsCheckpoint only applies
    /// @dev TODO to the rewards that been claimed and is in `totalRewardsClaimed` property, so if the address just
    /// @dev TODO deposits lots of amount of tokens and doesn't touch it for years, even though the rewards
    /// @dev TODO itself will be huge, it won't be updated in the state because the address hasn't called any
    /// @dev TODO functions that would trigger the rewards update in state. So the address wouldn't unlock Premium Tier.
    /// @dev TODO Also the decimals differ on different tokens so it's best to be different value for different tokens.
    uint public immutable totalClaimedRewardsCheckpoint = 10 * 10 ** 18;
    uint8 public constant premiumTierInterestPercentage = 120; /// @dev 120%

    /// @dev Contract constructor calling it's parent's constructor
    /// @dev We can also implement setting of the initial tokens and their rates here
    /// @param _agentsOtherThanSender list of addresses (agents) that will be able to vote, MSG.SENDER shouldn't be here
    constructor(
        address[] memory _agentsOtherThanSender
    ) SavingsAgent(_agentsOtherThanSender) {}

    /// @dev Modifier that checks if the token is supported by the contract
    modifier checkToken(address _token) {
        require(tokenAnnualRates[_token] > 0);
        _;
    }

    /// @notice deposit into the contract
    /// @dev interest % is only given on the deposited amount and not on the rewards, meaning
    /// @dev if address initially deposits 100 token and earns 2 tokens and has total 102 withdrawable
    /// @dev tokens, interest earned are still based on the deposited 100 tokens.
    /// @dev TODO Will be interested to also implement earning of interest based on rewards
    /// @param _token token address to deposit
    /// @param _amount amount to deposit
    function deposit(address _token, uint _amount) external checkToken(_token) {
        require(_amount > 0);
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        /// @dev if the address already has a deposit under this token, first calculate the rewards
        /// @dev for that balance and than update the state
        if (balanceState.lastBalanceUpdateTimestamp != 0) {
            uint rewards = _calculateRewards(_token, balanceState);
            balanceState.rewards += rewards;
        }
        balanceState.balance += _amount;
        balanceState.lastBalanceUpdateTimestamp = block.timestamp;
        emit Deposit(msg.sender, _token, _amount);
    }

    /// @notice withdraw only your deposited amount from the contract
    /// @dev If address has deposited 100 tokens and earned 5 tokens, with withdraw() function
    /// @dev they will be able to only get 100 tokens. 5 reward tokens can be withdrawn from claimRewards()
    /// @dev TODO These 2 functions can be merged together, see more details in comments below of claimRewards() function
    /// @param _token token address to withdraw
    /// @param _amount amount to withdraw
    function withdraw(
        address _token,
        uint _amount
    ) external checkToken(_token) {
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        require(balanceState.balance >= _amount);
        uint rewards = _calculateRewards(_token, balanceState);
        balanceState.rewards += rewards;
        balanceState.balance -= _amount;
        balanceState.lastBalanceUpdateTimestamp = block.timestamp;
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /// @notice withdraw only the rewards from the contract
    /// @dev TODO This function can be merged with the withdraw() function, and when the user withdraw some
    /// @dev TODO specific amount, first we can drain the rewards, and after its 0, than we can drain their
    /// @dev TODO deposited amount to ensure that they can get the maximum interest %,
    /// @dev because interest isn't given on reward amount (explained in comments of deposit())
    /// @param _token token address to withdraw rewards from
    /// @param _amount amount to withdraw rewards from
    function claimRewards(
        address _token,
        uint _amount
    ) external checkToken(_token) {
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        require(balanceState.rewards >= _amount);
        balanceState.rewards -= _amount;
        balanceState.totalRewardsClaimed += _amount;
        IERC20(_token).transfer(msg.sender, _amount);
        uint balance = IERC20(_token).balanceOf(address(this));
        if (balance <= balanceAlertThreshold)
            emit LowBalanceAlert(_token, balance, block.timestamp);
    }

    /// @notice View total amount of rewards that the address has at the current timestamp
    /// @dev `rewards` property in balanceState is only updated on stake() or withdraw() so it doesn't show full
    /// @dev amount of rewards, so this function calculates the full rewards and returns it.
    /// @param _token token address to withdraw rewards from
    /// @return totalRewards total amount of rewards that the address got at current timestamp
    function viewTotalRewards(
        address _token
    ) external view checkToken(_token) returns (uint totalRewards) {
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        uint rewards = _calculateRewards(_token, balanceState);
        totalRewards = rewards + balanceState.rewards;
    }

    /// @notice get all the supported tokens with their interest rates
    /// @dev pagination is included in function because the array is huge, we want to avoid iterating and returning this huge list
    /// @param _page number of page to return
    /// @param _itemsPerPage number of tokens per page
    function getSupportedTokens(
        uint _page,
        uint _itemsPerPage
    ) public view returns (address[] memory, uint16[] memory) {
        address[] memory addresses = new address[](supportedTokens.length);
        uint16[] memory annualInterestRates = new uint16[](
            supportedTokens.length
        );
        uint k;
        for (
            uint i = _itemsPerPage * (_page - 1);
            i < _itemsPerPage * _page;
            i++
        ) {
            address token = supportedTokens[i];
            addresses[k] = token;
            annualInterestRates[k] = tokenAnnualRates[token];
        }
        return (addresses, annualInterestRates);
    }

    /// @dev Private function for calculating rewards based on the balance, duration and the interest %
    /// @param _token token address
    /// @param balanceState struct of the BalanceState
    /// @return earnedRewards final calculated rewards earned
    function _calculateRewards(
        address _token,
        BalanceState memory balanceState
    ) private view returns (uint earnedRewards) {
        uint duration = block.timestamp -
            balanceState.lastBalanceUpdateTimestamp;
        uint rate = balanceState.totalRewardsClaimed >=
            totalClaimedRewardsCheckpoint
            ? (tokenAnnualRates[_token] * premiumTierInterestPercentage) / 100
            : tokenAnnualRates[_token];
        earnedRewards =
            ((balanceState.balance * duration * rate) / 10000) /
            (365 * 24 * 60 * 60); /// @dev calculating % for 1 second
    }
}
