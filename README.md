# Decentralized Voting System

## Overview

The **Decentralized Voting System** is a smart contract-based application designed to facilitate secure and transparent voting processes on the Ethereum blockchain. This system enables users to register as voters, nominate candidates, cast votes, and retrieve the election results, all while ensuring data integrity and fairness.

## Features

- **Voter Registration:** Users can register as voters by paying a registration fee.
- **Candidate Nomination:** Registered voters can nominate themselves or others as candidates.
- **Voting Mechanism:** Voters can vote for their preferred candidates during the election period.
- **Result Finalization:** The system automatically finalizes the list of eligible candidates and determines the election winner.

## Smart Contract Structure

### 1. `DecVotingSystem` Contract

This is the primary contract that manages the entire voting process. It contains functions for voter and candidate registration, voting, nomination, and finalizing election results.

#### Key Components:

- **Constructor:** Initializes the contract with the registration fee, nomination end time, and election end time.
- **Custom Errors:** Efficiently handles errors like double registration, insufficient fee payment, etc.
- **Modifiers:** Enforces access control, e.g., only registered voters can call certain functions.
- **Mappings and Arrays:** Manages voter and candidate data, storing information like addresses, vote counts, and nomination counts.

#### Events:
- `VoterRegistered`: Emitted when a voter successfully registers.
- `CandidateRegistered`: Emitted when a candidate is successfully registered.
- `CandidateFinalized`: Emitted after the candidate list is finalized.
- `VoterVoted`: Emitted when a voter successfully votes for a candidate.

#### Functions:

- **`registerAsVoter`:** Allows users to register as voters by paying the registration fee.
- **`registerAsCandidate`:** Enables registered voters to nominate themselves as candidates.
- **`nominateCandidate`:** Allows voters to nominate other candidates.
- **`finalizeCandidateList`:** Finalizes the list of eligible candidates after the nomination period.
- **`voteForCandidate`:** Allows voters to cast their votes for candidates.
- **`getElectionResult`:** Retrieves the winner of the election after the election period ends.

## Deployment

### Prerequisites

- [Foundry](https://getfoundry.sh/) - A blazing fast, portable, and modular toolkit for Ethereum application development.
- [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/) for JavaScript/TypeScript development.

### Installation

1. **Clone the repository:**
    ```bash
    git clone https://github.com/your-repository-url/DecVotingSystem.git
    cd DecVotingSystem
    ```

2. **Install dependencies:**
    ```bash
    npm install
    forge install
    ```

3. **Set up environment variables:**
    - Create a `.env` file in the root directory and add your Ethereum provider URL and private key.

    ```env
    ETH_PROVIDER_URL=<Your Ethereum Provider URL>
    PRIVATE_KEY=<Your Private Key>
    ```

### Deployment

You can deploy the contract using Foundry's `forge` tool.

1. **Compile the contract:**
    ```bash
    forge build
    ```

2. **Deploy the contract:**
    ```bash
    forge create --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY src/DecVotingSystem.sol:DecVotingSystem --constructor-args <registrationFee> <nominationEndTimeInHours> <electionEndTimeInHours>
    ```

    Replace `<registrationFee>`, `<nominationEndTimeInHours>`, and `<electionEndTimeInHours>` with appropriate values.

### Interacting with the Contract

Once deployed, you can interact with the contract using Foundry's `cast` commands or any Ethereum wallet like MetaMask.

### Example Commands

- **Register as a voter:**
    ```bash
    cast send --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY <ContractAddress> "registerAsVoter()" --value <registrationFeeInWei>
    ```

- **Nominate a candidate:**
    ```bash
    cast send --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY <ContractAddress> "nominateCandidate(address candidate)"
    ```

- **Vote for a candidate:**
    ```bash
    cast send --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY <ContractAddress> "voteForCandidate(address candidate)"
    ```

- **Finalize candidate list:**
    ```bash
    cast send --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY <ContractAddress> "finalizeCandidateList()"
    ```

- **Get election result:**
    ```bash
    cast call --rpc-url $ETH_PROVIDER_URL --private-key $PRIVATE_KEY <ContractAddress> "getElectionResult()"
    ```

## Testing

- Run unit tests using Foundry:
    ```bash
    forge test
    ```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
