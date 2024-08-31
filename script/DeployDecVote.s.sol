// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {DecVotingSystem} from "../src/DecVote.sol";

contract DeployVotingSystem is Script {
    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deployment parameters
        uint256 registrationFee = 0.01 ether; // Example registration fee
        uint256 nominationEndTime = 24; // 24 hours from deployment
        uint256 electionEndTime = 48; // 48 hours from deployment

        // Deploy the DecVotingSystem contract
        DecVotingSystem votingSystem = new DecVotingSystem(registrationFee, nominationEndTime, electionEndTime);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log the contract address
        console.log("DecVotingSystem deployed at:", address(votingSystem));
    }
}
