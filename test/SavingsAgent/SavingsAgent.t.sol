// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/SavingsAgent.sol";
import "../../src/Token.sol";

/// @dev This contract is a parent test contract for SavingsAgent contract
/// @dev Contains all the variables and the setUp() script
contract SavingsAgentTest is Test {
    /// @dev redeclaring the SavingsAgent's events
    event NewTokenProposed(uint proposalId);
    event NewTokenProposalVoted(
        address indexed voter,
        address delegate,
        uint proposalId,
        bool isInFavor
    );
    event NewTokenProposalFailed(uint proposalId);
    event NewTokenProposalExecuted(uint proposalId);

    SavingsAgent public savingsAgent;
    Token public token1;
    Token public token2;
    Token public token3;

    uint constant _TOKEN1_INITIAL_SUPPLY = 1000000 * 10 ** 18;
    uint constant _TOKEN2_INITIAL_SUPPLY = 1000000 * 10 ** 18;
    uint constant _TOKEN3_INITIAL_SUPPLY = 10 * 10 ** 18;

    address constant _AGENT_1 = address(1);
    address constant _AGENT_2 = address(2);
    address constant _NON_AGENT = address(3);

    address[] _initialAgents = [_AGENT_1, _AGENT_2];

    uint _requiredTokenBalanceUponAdding;
    uint _newTokenProposalDuration;

    function setUp() public {
        token1 = new Token("Test Token 1", "TTT", _TOKEN1_INITIAL_SUPPLY);
        token2 = new Token("Test Token 2", "TTK", _TOKEN2_INITIAL_SUPPLY);
        token3 = new Token("Test Token 2", "TTK", _TOKEN3_INITIAL_SUPPLY);
        savingsAgent = new SavingsAgent(_initialAgents);
        _requiredTokenBalanceUponAdding = savingsAgent
            .REQUIRED_TOKEN_BALANCE_UPON_ADDING();
        _newTokenProposalDuration = savingsAgent.NEW_TOKEN_PROPOSAL_DURATION();
        token1.transfer(address(savingsAgent), _TOKEN1_INITIAL_SUPPLY);
        token2.transfer(address(savingsAgent), _TOKEN2_INITIAL_SUPPLY);
    }
}

/// @dev Helper library containg helper functions
library Helpers {
    function enumToHash(
        SavingsAgent.Vote vote
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(vote)));
    }

    function enumToHash(
        SavingsAgent.ProposalStatus status
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(status)));
    }

    function calculateVotesNeededToPass(
        uint initialAgentNum
    ) internal pure returns (uint n) {
        uint agentsCount = initialAgentNum + 1;
        n = agentsCount % 2 == 0 ? agentsCount / 2 + 1 : (agentsCount + 1) / 2;
    }
}
