// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MiniSavingsAccountAgent.sol";

error UnsupportedToken();

contract MiniSavingsAccount is MiniSavingsAccountAgent {
    event Deposit(address indexed depositor, address token, uint amount);

    struct BalanceState {
        uint balance;
        uint rewards;
        uint lastBalanceUpdateTimestamp;
    }

    mapping(address => mapping(address => BalanceState))
        public userBalanceStates;

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
        agentsCount = _agentsOtherThanSender.length + 1;
    }

    modifier checkToken(address _token) {
        require(tokenAnnualRates[_token] > 0);
        _;
    }

    function deposit(address _token, uint _amount) external checkToken(_token) {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        BalanceState storage balanceState = userBalanceStates[msg.sender][
            _token
        ];
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
    }

    function _calculateRewards(
        address _token,
        uint _balance,
        uint _lastBalanceUpdateTimestamp
    ) private view returns (uint earnedRewards) {
        uint duration = block.timestamp - _lastBalanceUpdateTimestamp;
        earnedRewards =
            (_balance * duration * tokenAnnualRates[_token]) /
            (365 * 24 * 60 * 60);
    }
}
