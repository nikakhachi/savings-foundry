// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Token.sol";
import "../src/Faucet.sol";

contract TokenWithFaucetScript is Script {
    /// @dev Feel free to change the variable values to better suit your needs

    uint constant _INITIAL_TOKEN_SUPPLY = 1000 * 10 ** 18;
    uint constant _FAUCET_WITHDRAWABLE_AMOUNT = 10 * 10 ** 18;
    uint constant _FAUCET_COOLDOWN = 10;

    string constant _TOKEN_NAME = "Test Token";
    string constant _TOKEN_SYMBOL = "TTK";

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Token token = new Token(
            _TOKEN_NAME,
            _TOKEN_SYMBOL,
            _INITIAL_TOKEN_SUPPLY
        );
        new Faucet(
            address(token),
            _FAUCET_WITHDRAWABLE_AMOUNT,
            _FAUCET_COOLDOWN
        );

        vm.stopBroadcast();
    }
}
