// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.t.sol";

/// @dev This contract contains test cases specific to the voting of new token proposals of SavingsAgent contract
contract NewTokenProposalVotingTest is SavingsAgentTest {
    /// @dev New Token Proposal Voting

    /// @dev test voting of new token proposal
    function testVoteNewTokenProposal() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();

        savingsAgent.proposeNewToken(address(token1), 200);
        SavingsAgent.NewTokenProposal memory initialProposal = savingsAgent
            .getNewTokenProposalById(proposalId);

        /// @dev First voting and checking statuses
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, false);
        SavingsAgent.NewTokenProposal
            memory proposalAfterFirstVote = savingsAgent
                .getNewTokenProposalById(proposalId);
        assertEq(initialProposal.against + 1, proposalAfterFirstVote.against);
        assertEq(
            Helpers.enumToHash(savingsAgent.agentVotes(_AGENT_1, proposalId)),
            Helpers.enumToHash(SavingsAgent.Vote.AGAINST)
        );

        /// @dev Second voting and checking statuses
        /// @dev designed to make the proposal fail because failing triggers additional code
        /// @dev in a fuction and passing doesn't
        vm.prank(_AGENT_2);
        savingsAgent.voteNewToken(_AGENT_2, proposalId, false);
        SavingsAgent.NewTokenProposal
            memory proposalAfterSecondVote = savingsAgent
                .getNewTokenProposalById(proposalId);
        assertEq(
            proposalAfterSecondVote.against,
            proposalAfterFirstVote.against + 1
        );
        assertEq(
            proposalAfterSecondVote.inFavor,
            proposalAfterFirstVote.inFavor
        );
        assertEq(
            Helpers.enumToHash(savingsAgent.agentVotes(_AGENT_2, proposalId)),
            Helpers.enumToHash(SavingsAgent.Vote.AGAINST)
        );

        /// @dev Code now should automatically fail the proposal, so lets check the status
        /// @dev Event should also be emitted but we will check it in another test.
        assertEq(
            Helpers.enumToHash(proposalAfterSecondVote.status),
            Helpers.enumToHash(SavingsAgent.ProposalStatus.FAILED)
        );
    }

    /// @dev test voting of new token proposal with delegate
    function testDelegateVoteNewTokenProposal() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();

        savingsAgent.proposeNewToken(address(token1), 200);

        vm.prank(_AGENT_2);
        savingsAgent.delegateVote(_AGENT_1);

        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_2, proposalId, true);

        assertEq(
            Helpers.enumToHash(savingsAgent.agentVotes(_AGENT_2, proposalId)),
            Helpers.enumToHash(SavingsAgent.Vote.IN_FAVOR)
        );
        assertEq(
            Helpers.enumToHash(savingsAgent.agentVotes(_AGENT_1, proposalId)),
            Helpers.enumToHash(SavingsAgent.Vote.NO_VOTE)
        );
    }

    /// @dev test if the event is fired when voting of new token proposal
    function testVoteNewTokenEvent() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);

        vm.prank(_AGENT_1);
        vm.expectEmit(true, false, false, true);
        emit NewTokenProposalVoted(_AGENT_1, _AGENT_1, proposalId, true);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, true);
    }

    /// @dev Checks if the event will be triggered when the automatical failure will happen
    /// @dev after enough voters will vote against
    function testVoteNewTokenAutomaticFailEvent() public {
        uint proposalId = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);

        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, proposalId, false);

        vm.prank(_AGENT_2);
        vm.expectEmit(false, false, false, true);
        emit NewTokenProposalFailed(proposalId);
        savingsAgent.voteNewToken(_AGENT_2, proposalId, false);
    }

    /// @dev test if it reverts if agent tries to vote twice
    function testShouldNotDoubleVoteNewTokenProposal() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, false);
        vm.expectRevert(SavingsAgent.AlreadyVoted.selector);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, false);
    }

    /// @dev test if it reverts if agent tries to vote with invalid id
    function testShouldNotVoteNonExistingNewTokenProposal() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.expectRevert(SavingsAgent.ProposalNotFound.selector);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id + 1, false);
    }

    /// @dev test if it reverts if agent tries to vote proposal with ended voting time
    function testShouldNotVoteEndedNewTokenProposal() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        skip(_newTokenProposalDuration);
        vm.expectRevert(SavingsAgent.VotingEnded.selector);
        vm.prank(_AGENT_1);
        savingsAgent.voteNewToken(_AGENT_1, id, false);
    }

    /// @dev test if it reverts if agent tries to vote with invalid delegate
    function testShouldNotVoteNewTokenProposalWithInvalidDelegate() public {
        uint id = savingsAgent.newTokenProposalsCount();
        savingsAgent.proposeNewToken(address(token1), 200);
        vm.prank(_AGENT_1);
        vm.expectRevert(SavingsAgent.InvalidDelegate.selector);
        savingsAgent.voteNewToken(_AGENT_2, id, false);
    }
}
