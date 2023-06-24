// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

/// @dev Custom errors
error InsufficientFunds();
error InvalidAddress();
error TooManyRequests();

/// @title Faucet
/// @author Nika Khachiashvili
/// @notice A contract that allows users to withdraw ERC20 tokens in a controlled manner.
contract Faucet {
    event Withdraw(address indexed user, uint timestamp);

    IERC20 public token; /// @dev Reference to the ERC20 token contract.

    uint public withdrawableAmount; /// @dev Amount of tokens that can be withdrawn per request.
    uint public cooldown; /// @dev Cooldown period between two consecutive withdrawals for a user.

    mapping(address => uint) public withdrawalTimes; /// @dev Mapping to track the last withdrawal timestamp for each user.

    /// @dev Contract constructor.
    /// @param _token The address of the ERC20 token contract.
    /// @param _withdrawableAmount The amount of tokens that can be withdrawn per request.
    /// @param _cooldown The cooldown period between two consecutive withdrawals for a user.
    constructor(address _token, uint _withdrawableAmount, uint _cooldown) {
        token = IERC20(_token);
        withdrawableAmount = _withdrawableAmount;
        cooldown = _cooldown;
    }

    /// @dev Function to withdraw tokens from the faucet.
    /// @notice Users can call this function to withdraw tokens from the faucet.
    function withdraw() external {
        if (msg.sender == address(0)) revert InvalidAddress(); /// @dev Check if the sender address is invalid

        /// @dev Check if the faucet has insufficient funds
        if (token.balanceOf(address(this)) < withdrawableAmount)
            revert InsufficientFunds();

        /// @dev Make sure that user hasn't already withdrawn within the cooldown time
        if (withdrawalTimes[msg.sender] > block.timestamp)
            revert TooManyRequests();

        withdrawalTimes[msg.sender] = block.timestamp + cooldown; /// @dev Set the withdrawal timestamp for the user
        token.transfer(msg.sender, withdrawableAmount); /// @dev Transfer tokens from the faucet to the user
        emit Withdraw(msg.sender, block.timestamp); /// @dev Emit the Withdraw event
    }
}
