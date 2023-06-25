// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.t.sol";

/// @dev This contract contains test cases specific to the execution of new token proposals of SavingsAgent contract
contract NewTokenProposalExecutingTest is SavingsAgentTest {
    /// @dev test the execution of the new token proposal with enough inFavor votes
    function testExecutePassingNewTokenProposal() public {
        uint id = savingsAgent.newTokenProposalsCount();
        uint16 annualRate = 200;
        savingsAgent.proposeNewToken(address(token1), annualRate);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, true);
        skip(_newTokenProposalDuration);

        bool passed = savingsAgent.executeNewTokenProposal(id);
        assertTrue(passed);

        SavingsAgent.NewTokenProposal memory proposal = savingsAgent
            .getNewTokenProposalById(id);

        assertEq(savingsAgent.getTokenAnnualRate(address(token1)), annualRate);
        assertEq(
            Helpers.enumToHash(proposal.status),
            Helpers.enumToHash(SavingsAgent.ProposalStatus.EXECUTED)
        );
    }

    /// @dev test if the event is fired when executing new token proposal with enough inFavor votes
    function testExecutePassingNewTokenProposalEvent() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, true);
        skip(_newTokenProposalDuration);

        vm.expectEmit(false, false, false, true);
        emit NewTokenProposalExecuted(id);
        savingsAgent.executeNewTokenProposal(id);
    }

    /// @dev test the execution of the new token proposal with not enough inFavor votes
    function testExecuteFailingNewTokenProposal() public {
        uint id = savingsAgent.newTokenProposalsCount();
        uint16 annualRate = 200;
        savingsAgent.proposeNewToken(address(token1), annualRate);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, false);
        skip(_newTokenProposalDuration);

        bool passed = savingsAgent.executeNewTokenProposal(id);
        assertFalse(passed);

        SavingsAgent.NewTokenProposal memory proposal = savingsAgent
            .getNewTokenProposalById(id);

        assertEq(
            Helpers.enumToHash(proposal.status),
            Helpers.enumToHash(SavingsAgent.ProposalStatus.FAILED)
        );
    }

    /// @dev test if the event is fired when executing new token proposal with not enough inFavor votes
    function testExecuteFailingNewTokenProposalEvent() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, false);
        skip(_newTokenProposalDuration);

        vm.expectEmit(false, false, false, true);
        emit NewTokenProposalFailed(id);
        savingsAgent.executeNewTokenProposal(id);
    }

    /// @dev test if it reverts if executing non-existing new token proposal
    function testExecutingInvalidNewTokenProposal() public {
        vm.expectRevert(SavingsAgent.ProposalNotFound.selector);
        savingsAgent.executeNewTokenProposal(120);
    }

    /// @dev test if it reverts if executing new token proposal that's in progress
    function testExecutingInProgressNewTokenProposal() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.expectRevert(SavingsAgent.VotingInProgress.selector);
        savingsAgent.executeNewTokenProposal(proposalId);
    }

    /// @dev test if it reverts if executing new token proposal that's already executed (failed or passed)
    function testExecutingExecutedNewTokenProposal() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, true);
        skip(_newTokenProposalDuration);

        savingsAgent.executeNewTokenProposal(proposalId);

        vm.expectRevert(SavingsAgent.ProposalNotPending.selector);
        savingsAgent.executeNewTokenProposal(proposalId);
    }

    /// @dev test if it reverts if executing new token proposal but if contract has insufficient balance of that token
    function testExecutingNewTokenProposalWithInsufficientBalance() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, true);
        skip(_newTokenProposalDuration);

        vm.prank(address(savingsAgent));
        token1.approve(_NON_AGENT, _TOKEN1_INITIAL_SUPPLY);

        vm.prank(_NON_AGENT);
        token1.transferFrom(
            address(savingsAgent),
            _NON_AGENT,
            _TOKEN1_INITIAL_SUPPLY
        );

        vm.expectRevert(SavingsAgent.InsufficientBalance.selector);
        savingsAgent.executeNewTokenProposal(proposalId);
    }

    /// @dev test if it reverts if executing new token proposal with token that's already supported
    function testExecutingNewTokenProposalWithInvalidToken() public {
        uint proposal1Id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposal1Id, true);
        skip(_newTokenProposalDuration);

        uint proposal2Id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposal2Id, true);
        skip(_newTokenProposalDuration);

        savingsAgent.executeNewTokenProposal(proposal1Id);

        vm.expectRevert(SavingsAgent.InvalidToken.selector);
        savingsAgent.executeNewTokenProposal(proposal2Id);
    }
}
