// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/SavingsAgent.sol";
import "../src/Token.sol";

/// @dev This contract has function with long names, such as `testNonAgentShouldNotProposeNewToken`
/// @dev I could've written just `testNonAgentShouldNotPropose` but I'm still specifying the proposal everywhere
/// @dev because if it was a real project, most likely (or maybe) we would've added now proposals and voting
/// @dev systems for other features, and that's why I'm specifying them
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

    /// @dev Proposing New Token

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
        assertEq(proposal.votesNeededToPass, _calculateVotesNeededToPass());
        assertEq(proposal.against, 0);
        assertEq(proposal.inFavor, 1);
        assertEq(
            _enumToHash(proposal.status),
            _enumToHash(SavingsAgent.ProposalStatus.PENDING)
        );
        assertEq(proposal.annualRate, 200);
        assertEq(savingsAgent.newTokenProposalsCount(), id + 1);
        assertEq(
            _enumToHash(savingsAgent.agentVotes(address(this), id)),
            _enumToHash(SavingsAgent.Vote.IN_FAVOR)
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
            _enumToHash(savingsAgent.agentVotes(_AGENT_1, proposalId)),
            _enumToHash(SavingsAgent.Vote.AGAINST)
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
            _enumToHash(savingsAgent.agentVotes(_AGENT_2, proposalId)),
            _enumToHash(SavingsAgent.Vote.AGAINST)
        );

        /// @dev Code now should automatically fail the proposal, so lets check the status
        /// @dev Event should also be emitted but we will check it in another test.
        assertEq(
            _enumToHash(proposalAfterSecondVote.status),
            _enumToHash(SavingsAgent.ProposalStatus.FAILED)
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
            _enumToHash(savingsAgent.agentVotes(_AGENT_2, proposalId)),
            _enumToHash(SavingsAgent.Vote.IN_FAVOR)
        );
        assertEq(
            _enumToHash(savingsAgent.agentVotes(_AGENT_1, proposalId)),
            _enumToHash(SavingsAgent.Vote.NO_VOTE)
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

    /// @dev Executing New Token Proposals

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
            _enumToHash(proposal.status),
            _enumToHash(SavingsAgent.ProposalStatus.EXECUTED)
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
            _enumToHash(proposal.status),
            _enumToHash(SavingsAgent.ProposalStatus.FAILED)
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

    /// @dev Delegations

    /// @dev test delegate vote
    function testDelegateVote() public {
        vm.prank(_AGENT_1);
        savingsAgent.delegateVote(_AGENT_2);

        assertEq(savingsAgent.getDelegate(_AGENT_1), _AGENT_2);
    }

    /// @dev test revoke delegate
    function testRevokeDelegate() public {
        vm.prank(_AGENT_1);
        savingsAgent.delegateVote(_AGENT_2);

        vm.prank(_AGENT_1);
        savingsAgent.revokeDelegate();

        assertEq(savingsAgent.getDelegate(_AGENT_1), address(0));
    }

    /// @dev Helper functions

    function _enumToHash(
        SavingsAgent.Vote vote
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(vote)));
    }

    function _enumToHash(
        SavingsAgent.ProposalStatus status
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(status)));
    }

    function _calculateVotesNeededToPass() private view returns (uint n) {
        uint agentsCount = _initialAgents.length + 1;
        n = agentsCount % 2 == 0 ? agentsCount / 2 + 1 : (agentsCount + 1) / 2;
    }
}
