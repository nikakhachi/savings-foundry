// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.t.sol";

/// @dev This contract contains test cases specific to the proposing of new token proposals of SavingsAgent contract
contract NewTokenProposingTest is SavingsAgentTest {
    /// @dev test proposing of new token
    function testProposeNewToken() public {
        uint id = savingsAgent.newTokenProposalsCount();
        uint16 annualRate = 200;

        savingsAgent.proposeNewToken(address(token1), annualRate);

        SavingsAgent.NewTokenProposal memory proposal = savingsAgent
            .getNewTokenProposalById(id);

        assertEq(proposal.id, id);
        assertEq(proposal.token, address(token1));
        assertEq(
            proposal.voteEndsAt,
            block.timestamp + _newTokenProposalDuration
        );
        assertEq(
            proposal.votesNeededToPass,
            Helpers.calculateVotesNeededToPass(_initialAgents.length)
        );
        assertEq(proposal.against, 0);
        assertEq(proposal.inFavor, 1);
        assertEq(
            Helpers.enumToHash(proposal.status),
            Helpers.enumToHash(SavingsAgent.ProposalStatus.PENDING)
        );
        assertEq(proposal.annualRate, 200);
        assertEq(savingsAgent.newTokenProposalsCount(), id + 1);
        assertEq(
            Helpers.enumToHash(savingsAgent.agentVotes(address(this), id)),
            Helpers.enumToHash(SavingsAgent.Vote.IN_FAVOR)
        );
    }

    /// @dev test if the event is fired when proposing of new token (1st proposal)
    function testProposeNewTokenEvent() public {
        uint initialProposalCount = savingsAgent.newTokenProposalsCount();
        vm.expectEmit(false, false, false, true);
        emit NewTokenProposed(initialProposalCount);
        savingsAgent.proposeNewToken(address(token1), 200);
    }

    /// @dev test if the event is fired when proposing of new token (2nd proposal)
    function testProposeNewTokenEvent2() public {
        uint initialProposalCount = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.expectEmit(false, false, false, true);
        emit NewTokenProposed(initialProposalCount + 1);
        savingsAgent.proposeNewToken(address(token2), 200);
    }

    /// @dev test if it reverts when non-agent tries to propose new token
    function testNonAgentShouldNotProposeNewToken() public {
        vm.prank(_NON_AGENT);
        vm.expectRevert();
        savingsAgent.proposeNewToken(address(token1), 200);
    }

    /// @dev test if it reverts when agent tries to propose already supported token
    function testShouldNotProposeExistingToken() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, true);
        vm.prank(_AGENT_2);
        savingsAgent.voteNewToken(_AGENT_2, proposalId, true);
        skip(_newTokenProposalDuration);
        savingsAgent.executeNewTokenProposal(proposalId);
        vm.expectRevert(SavingsAgent.InvalidToken.selector);
        savingsAgent.proposeNewToken(address(token1), 200);
    }

    /// @dev test if it reverts when agent tries to propose new token, but if contract
    /// @dev has insufficient balance of that token
    function testShouldNotProposeNewTokenWithInsufficientBalance() public {
        vm.expectRevert(SavingsAgent.InsufficientBalance.selector);
        savingsAgent.proposeNewToken(address(token3), 200);
    }
}
