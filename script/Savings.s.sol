// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Savings.sol";
import "../src/Token.sol";
import "../src/Faucet.sol";

contract SavingsScript is Script {
    /// @dev Feel free to change the variable values to better suit your needs

    address[] _initialAgents = [address(1), address(0)];

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new Savings(_initialAgents);

        vm.stopBroadcast();
    }
}
