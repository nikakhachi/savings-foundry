# Mini Savings Account

decentralized finance (DeFi) platform built on the Ethereum blockchain, offering users the opportunity to deposit supported tokens and earn competitive annual interest rates. As users accumulate rewards, they have the chance to ascend to the premium tier, unlocking an additional 20% interest boost on their deposits. The platform operates on a voting system, where platform agents can propose and add new tokens, ensuring a diverse range of options for users. Experience the power of decentralized savings with Mini Savings Account.

The project is ongoing and there are lots of things that can be implemented. Some possible features and implementations are mentioned in the code that describes the behaviors and the supposed implementation, so feel free to contribute!

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Development](#development)
- [Contact](#contact)

## Features

- Users can deposit into the contract (any supported token by the contract), hold it, and earn annual interest (the rate differs on every token).
- Premium Tier is available for the users that will earn more than a certain amount of rewards. Premium tier users enjoy increased interest rates by 20%.
- The contract operates on the voting system. Agents of the contract can only add new tokens through voting. Delegates are available.
- In order for new token proposals to be proposed or executed, the contract must have some specific minimum amount to ensure safe interest giving.
- Alert will be given if the contract's balance of some specific token reaches the threshold, to ensure timely balance fill to ensure safe interest giving.

## Prerequisites

Before deploying the smart contract, ensure that you have the following installed:

- `foundryup` - If you don't have it installed, you can run `curl -L https://foundry.paradigm.xyz | bash` in your terminal.

  Read More About the Installation from [Foundry Book](https://book.getfoundry.sh/getting-started/installation)

## Getting Started

Follow the steps below to get the smart contract up and running:

1. Clone this repository to your local machine.
2. Install the project dependencies by running `forge install` in the root directory.
3. Compile the files with `forge build`.

If you would like to deploy a smart contract on your local machine do the following:

1. `anvil` to run a local node.
2. Update the variables in files of the `script/` folder to our needs.
3. Deploy the smart contract with `forge script script/{filename}.s.sol --fork-url http://localhost:8545 --broadcast`

   Read More About the Deployment from the [Foundry Book](https://book.getfoundry.sh/forge/deploying)

## Development

To contribute to the development of this project, follow the steps below:

1. Clone this repository to your local machine.
2. Get the smart contract up and running following the steps in [Getting Started](#getting-started).
3. Create a new branch for your changes: `git checkout -b my-new-feature`.
4. Make the necessary modifications and additions.
5. Test Smart Contract with `forge test` in the root directory.
6. Commit and push your changes: `git commit -m 'Add some feature' && git push origin my-new-feature`.
7. Submit a pull request detailing your changes and their benefits.

## Contact

For any questions or inquiries, please contact [Nika Khachiashvili](mailto:n.khachiashvili1@gmail.com).
