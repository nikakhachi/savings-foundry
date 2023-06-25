// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/AccessControlEnumerable.sol";

/// @dev Custom errors
error InvalidToken();
error InsufficientBalance();
error NonAgent();
error ProposalNotFound();
error AlreadyVoted();
error InvalidDelegate();
error VotingEnded();
error VotingInProgress();
error ProposalNotPending();

/// @title MiniSavingsAccountAgent
/// @author Nika Khachiashvili
/// @dev The contract contains variables and function for proposing and voting for adding new tokens
/// @dev TODO Lots of other functions can also be added for voting for example updating the annual interest rate,
/// @dev TODO adding or revoking the current agents, or even proposing a different tiers with different interest rates for tokens
contract MiniSavingsAccountAgent is AccessControlEnumerable {
    event NewTokenProposed(uint proposalId);
    event NewTokenProposalVoted(
        address indexed voter,
        address delegate,
        uint proposalId,
        bool isInFavor
    );
    event NewTokenProposalFailed(uint proposalId);
    event NewTokenProposalExecuted(uint proposalId);

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE"); /// @dev Role identifier for agents

    /// @dev Vote Status of the agent in reference to the specific proposal
    enum Vote {
        NO_VOTE,
        IN_FAVOR,
        AGAINST
    }

    /// @dev Status of the proposal
    enum ProposalStatus {
        PENDING,
        EXECUTED,
        FAILED
    }

    /// @dev When proposing or executing the addition of a new token, it will be essentioal for contract
    /// @dev to have this minimum balance of the token to ensure safe giving of the interest
    uint public constant requiredTokenBalanceUponAdding = 10000 * 10 ** 18;

    /// @dev Interval between proposing new token addition and executing it
    /// @dev During this interval agents will be able to vote
    uint public newTokenProposalDuration = 1 weeks;

    /// @dev mapping of tokens with their annual rates. FORMAT  350 = 3.50%
    /// @dev If the annual rate for token is 0 (default), it means that the token isn't supported
    mapping(address => uint16) public tokenAnnualRates;

    /// @dev list of supported tokens
    address[] public supportedTokens;

    struct NewTokenProposal {
        uint id;
        address token;
        uint voteEndsAt;
        uint votesNeededToPass;
        uint against;
        uint inFavor;
        ProposalStatus status;
        uint16 annualRate;
    }

    mapping(uint => NewTokenProposal) public newTokenProposals;
    uint newTokenProposalsCount;

    /// @dev mapping keeping track of agent votes for the specific proposals
    mapping(address => mapping(uint => Vote)) public agentVotes;

    /// @dev mapping keeping track of address delegates
    mapping(address => address) public delegates;

    /// @dev Proposing the addition of a new token
    /// @param _token token address that is proposed
    /// @param _annualRate annual interest rate of the proposed token. FORMAT  350 = 3.50%
    function proposeNewToken(
        address _token,
        uint16 _annualRate
    ) external onlyRole(AGENT_ROLE) {
        if (tokenAnnualRates[_token] != 0) revert InvalidToken();
        if (
            IERC20(_token).balanceOf(address(this)) <
            requiredTokenBalanceUponAdding
        ) revert InsufficientBalance();

        uint votesNeededToPass = _calculateVotesNeededToPass();
        newTokenProposals[newTokenProposalsCount] = NewTokenProposal(
            newTokenProposalsCount,
            _token,
            block.timestamp + newTokenProposalDuration,
            votesNeededToPass,
            0,
            1,
            ProposalStatus.PENDING,
            _annualRate
        );
        emit NewTokenProposed(newTokenProposalsCount);
        newTokenProposalsCount++;
    }

    /// @dev Voting for the new token proposal
    /// @param voter address which votes directly or indirectly (delegate)
    /// @param id proposal id
    /// @param isInFavor is in favor or against the proposal
    function voteNewToken(
        address voter,
        uint id,
        bool isInFavor
    ) external onlyRole(AGENT_ROLE) {
        if (voter != msg.sender && delegates[voter] == msg.sender)
            revert InvalidDelegate();
        if (agentVotes[voter][id] != Vote.NO_VOTE) revert AlreadyVoted();
        NewTokenProposal storage proposal = newTokenProposals[id];
        if (proposal.voteEndsAt == 0) revert ProposalNotFound();
        if (proposal.voteEndsAt <= block.timestamp) revert VotingEnded();
        if (isInFavor) {
            proposal.inFavor++;
            agentVotes[voter][id] = Vote.IN_FAVOR;
        } else {
            proposal.against++;
            agentVotes[voter][id] = Vote.AGAINST;
        }
        emit NewTokenProposalVoted(voter, msg.sender, id, isInFavor);
        /// @dev If all the agents have voted we automatically calculate count of
        /// @dev inFavor agents and automatically FAIL the proposal if it's less than
        /// @dev the count needed for the proposal to pass
        if (
            proposal.against + proposal.inFavor >=
            getRoleMemberCount(AGENT_ROLE) &&
            proposal.inFavor < proposal.votesNeededToPass
        ) {
            proposal.status = ProposalStatus.FAILED;
            emit NewTokenProposalFailed(id);
        }
    }

    /// @dev Executing the new token proposal if the voting time has ended and it passes
    /// @param id proposal id
    function executeNewTokenProposal(uint id) external {
        NewTokenProposal storage proposal = newTokenProposals[id];
        if (proposal.voteEndsAt == 0) revert ProposalNotFound();
        if (proposal.voteEndsAt >= block.timestamp) revert VotingInProgress();
        if (proposal.status != ProposalStatus.PENDING)
            revert ProposalNotPending();
        if (
            IERC20(proposal.token).balanceOf(address(this)) <
            requiredTokenBalanceUponAdding
        ) revert InsufficientBalance();
        /// @dev when the voting period ends, there can be case when not all agents have voted.
        /// @dev in that case we will decide here if the proposal failed and update the status
        if (proposal.inFavor < proposal.votesNeededToPass) {
            proposal.status = ProposalStatus.FAILED;
            emit NewTokenProposalFailed(id);
        } else {
            tokenAnnualRates[proposal.token] = proposal.annualRate;
            proposal.status = ProposalStatus.EXECUTED;
            supportedTokens.push(proposal.token);
            emit NewTokenProposalExecuted(id);
        }
    }

    /// @dev Delegate your vote to another agent
    /// @param _delegateTo address that you are delegating to
    function deletageVote(address _delegateTo) external onlyRole(AGENT_ROLE) {
        delegates[msg.sender] = _delegateTo;
    }

    /// @dev Revoking your delegation
    function revokeDelegate() external onlyRole(AGENT_ROLE) {
        delegates[msg.sender] = address(0);
    }

    /// @dev Calculates the votes needed for the proposal to pass based on
    /// @dev current agent count. The number will always be more than half
    /// @dev of the current agents count
    /// @return n vote number needed for the proposal to pass
    function _calculateVotesNeededToPass() private view returns (uint n) {
        uint agentsCount = getRoleMemberCount(AGENT_ROLE);
        n = agentsCount % 2 == 0 ? agentsCount / 2 + 1 : (agentsCount + 1) / 2;
    }
}
