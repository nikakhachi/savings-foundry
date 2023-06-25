// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SavingsAgent.t.sol";

/// @dev This contract contains test cases specific to the delegation functions of SavingsAgent contract
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
