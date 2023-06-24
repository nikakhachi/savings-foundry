// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MiniSavingsAccountAgent.sol";

/// @title MiniSavingsAccount
/// @author Nika Khachiashvili
/// @dev The contract is the main contract that will be deployed and contains the external functions for everyone
/// @dev For depositing, withdrawing and getting the rewards
/// @dev Possible feature additions are mentioned in the comments of deposit() and earnRewards()
contract MiniSavingsAccount is MiniSavingsAccountAgent {
    event Deposit(address indexed depositor, address token, uint amount);
    event LowBalanceAlert(address indexed token, uint balance, uint timestamp);

    /// @dev If the balance hits this number, LowBalanceAlert will be evoked.
    /// @dev Can be implemented that it's unique for each token and also modifible,
    /// @dev but let's leave it like that for now.
    uint public constant balanceAlertThreshold = 3000 * 10 ** 18;

    struct BalanceState {
        uint balance;
        uint rewards;
        uint lastBalanceUpdateTimestamp;
    }

    /// @dev Balance states for each token for each user
    mapping(address => mapping(address => BalanceState))
        public userBalanceStates;

    /// @dev Contract constructor.
    /// @param _agentsOtherThanSender list of addresses (agents) that will be able to vote, MSG.SENDER shouldn't be here
    /// @param _supportedTokens Tokens that will be supported initially
    /// @param _tokenAnnualRates Annual rates of the respective _supportedTokens
    constructor(
        address[] memory _agentsOtherThanSender,
        address[] memory _supportedTokens,
        uint16[] memory _tokenAnnualRates
    ) {
        require(_supportedTokens.length == _tokenAnnualRates.length);
        for (uint i = 0; i < _supportedTokens.length; i++) {
            tokenAnnualRates[_supportedTokens[i]] = _tokenAnnualRates[i];
        }
        isAgent[msg.sender] = true;
        for (uint i = 0; i < _agentsOtherThanSender.length; i++) {
            isAgent[_agentsOtherThanSender[i]] = true;
        }
        /// @dev we are setting the value here and not in the loop by incrementing,
        /// @dev because changing the state only once costs less gas.
        agentsCount = _agentsOtherThanSender.length + 1;
    }

    /// @dev Modifier that check if the token is supported
    modifier checkToken(address _token) {
        require(tokenAnnualRates[_token] > 0);
        _;
    }

    /// @notice deposit into the contract
    /// @dev interest % is only given on the deposited amount and not on the rewards, meaning
    /// @dev if address initially deposits 100 token and earns 2 tokens and has total 102 withdrawable
    /// @dev tokens, interest earned are still based on the deposited 100 tokens.
    /// @param _token token address to deposit
    /// @param _amount amount to deposit
    function deposit(address _token, uint _amount) external checkToken(_token) {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        /// @dev if the address already has a deposit under this token, first calculate the rewards
        /// @dev for that balance and than update the state
        if (balanceState.lastBalanceUpdateTimestamp != 0) {
            uint rewards = _calculateRewards(
                _token,
                balanceState.balance,
                balanceState.lastBalanceUpdateTimestamp
            );
            balanceState.rewards += rewards;
        }
        balanceState.balance += _amount;
        balanceState.lastBalanceUpdateTimestamp = block.timestamp;
        emit Deposit(msg.sender, _token, _amount);
    }

    /// @notice withdraw only your deposited amount from the contract
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
        uint rewards = _calculateRewards(
            _token,
            balanceState.balance,
            balanceState.lastBalanceUpdateTimestamp
        );
        balanceState.rewards += rewards;
        balanceState.balance -= _amount;
        balanceState.lastBalanceUpdateTimestamp = block.timestamp;
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /// @notice withdraw only the rewards from the contract
    /// @dev This function can be merged with the withdraw() function, and when the user withdraw soem
    /// @dev specific amount, first we can drain the rewards, and after its 0, than we can drain their
    /// @dev deposited amount to ensure that they can the maximum interest %
    /// @dev because interest isn't given on reward amount (explained in comments of deposit())
    /// @param _token token address to withdraw rewards from
    /// @param _amount amount to withdraw rewards from
    function getRewards(
        address _token,
        uint _amount
    ) external checkToken(_token) {
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
        require(balanceState.rewards >= _amount);
        balanceState.rewards -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
        uint balance = IERC20(_token).balanceOf(address(this));
        if (balance <= balanceAlertThreshold)
            emit LowBalanceAlert(_token, balance, block.timestamp);
    }

    /// @dev Private function for calculating rewards based on the balance, duration and the interest %
    /// @param _token token address
    /// @param _balance address' balance for that token
    /// @param _lastBalanceUpdateTimestamp timestamp of last updated balance
    function _calculateRewards(
        address _token,
        uint _balance,
        uint _lastBalanceUpdateTimestamp
    ) private view returns (uint earnedRewards) {
        uint duration = block.timestamp - _lastBalanceUpdateTimestamp;
        earnedRewards =
            (_balance * duration * tokenAnnualRates[_token]) /
            (365 * 24 * 60 * 60); /// @dev calculating % for 1 second
    }
}
