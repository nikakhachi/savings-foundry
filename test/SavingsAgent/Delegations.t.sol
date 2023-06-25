// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.t.sol";

/// @dev This contract has function with long names, such as `testNonAgentShouldNotProposeNewToken`
/// @dev I could've written just `testNonAgentShouldNotPropose` but I'm still specifying the proposal everywhere
/// @dev because if it was a real project, most likely (or maybe) we would've added now proposals and voting
/// @dev systems for other features, and that's why I'm specifying them
contract DelegationsTest is SavingsAgentTest {
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
}
