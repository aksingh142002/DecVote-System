// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployVotingSystem} from "../script/DeployDecVote.s.sol";
import {DecVotingSystem} from "../src/DecVote.sol";

contract TestVotingSystem is Test {
    // Test constants
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    string NAME = "Developer1";
    uint256 constant SEND_VALUE = 0.01 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    // Test variables
    address deployer;
    DecVotingSystem test_DecVote;

    // Setup function to deploy the voting system contract
    function setUp() external {
        DeployVotingSystem deploy = new DeployVotingSystem();
        test_DecVote = deploy.run();
        deployer = msg.sender;
        vm.deal(USER, STARTING_BALANCE); // Give USER a starting balance
    }

    // Test constructor values after deployment
    function test_constructor() public {
        uint256 _registrationFee = 0.01 ether;
        uint256 _nominationEndTime = 2; // in hours
        uint256 _electionEndTime = 3; // in hours

        DecVotingSystem newDecVote = new DecVotingSystem(_registrationFee, _nominationEndTime, _electionEndTime);

        assertEq(newDecVote.i_owner(), address(this));
        assertEq(newDecVote.i_registration_fee(), _registrationFee);
        assertEq(newDecVote.i_nomination_endTime(), block.timestamp + (_nominationEndTime * 1 hours));
        assertEq(newDecVote.i_election_endTime(), block.timestamp + (_electionEndTime * 1 hours));
    }

    // Modifier to register a user as a voter before each test
    modifier voter() {
        vm.prank(USER);
        test_DecVote.registerAsVoter();
        _;
    }

    // Modifier to register a user as a candidate before each test
    modifier candidate() {
        vm.startPrank(USER);
        test_DecVote.registerAsVoter();
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);
        vm.stopPrank();
        _;
    }

    // Test voter registration functionality
    function test_registerAsVoter() public {
        vm.startPrank(USER);

        // Check that USER is not registered initially
        address checkAddress = test_DecVote.getVoterData(USER).voterAddress;
        assertNotEq(USER, checkAddress);

        // Register as voter and expect an event
        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.VoterRegistered(USER);
        test_DecVote.registerAsVoter();

        // Ensure that registering twice throws an error
        vm.expectRevert(DecVotingSystem.AlreadyRegisteredError.selector);
        test_DecVote.registerAsVoter();

        vm.stopPrank();
    }

    // Test candidate registration functionality
    function test_registerAsCandidate() public voter {
        vm.startPrank(USER);

        // Test registering with zero value throws an error
        vm.expectRevert(DecVotingSystem.InputError.selector);
        test_DecVote.registerAsCandidate{value: 0}(NAME);

        // Register as candidate and expect an event
        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.CandidateRegistered(NAME, USER);
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);

        // Ensure that registering twice throws an error
        vm.expectRevert(DecVotingSystem.AlreadyRegisteredError.selector);
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);

        vm.stopPrank();
    }

    // Test nomination functionality
    function test_nominateCandidate() public candidate {
        vm.startPrank(USER);

        // Nominate the candidate
        test_DecVote.nominateCandidate(USER);

        // Ensure a candidate cannot be nominated twice
        vm.expectRevert(DecVotingSystem.AlreadyNominatedError.selector);
        test_DecVote.nominateCandidate(USER);

        vm.stopPrank();

        // Another user attempts to nominate after the time has passed
        vm.startPrank(USER2);
        test_DecVote.registerAsVoter();

        vm.expectRevert(DecVotingSystem.NotRegisteredError.selector);
        test_DecVote.nominateCandidate(USER2);

        vm.warp(block.timestamp + 25 hours);
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.nominateCandidate(USER);

        vm.stopPrank();
    }

    // Test finalizing candidate list functionality
    function test_finalizeCandidateList() public {
        // Setup for multiple candidates
        address[3] memory candidates = [makeAddr("candidate0"), makeAddr("candidate1"), makeAddr("candidate2")];
        string[3] memory candidateNames = ["Candidate0", "Candidate1", "Candidate2"];

        for (uint256 i = 0; i < candidates.length; i++) {
            vm.deal(candidates[i], STARTING_BALANCE);
            vm.startPrank(candidates[i]);
            test_DecVote.registerAsVoter();
            test_DecVote.registerAsCandidate{value: SEND_VALUE}(candidateNames[i]);
            test_DecVote.nominateCandidate(candidates[i]);
            vm.stopPrank();
        }

        // Ensure that finalizing candidate list before nomination end time fails
        vm.startPrank(deployer);
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.finalizeCandidateList();

        // Warp time to after the nomination end time and finalize
        vm.warp(block.timestamp + (25 hours));
        test_DecVote.finalizeCandidateList();

        // Check that the candidate list was finalized
        address finalizedCandidate = test_DecVote.getFinalList(0);
        assertEq(finalizedCandidate, candidates[0]);

        vm.expectRevert(DecVotingSystem.IndexOutOfBoundsError.selector);
        test_DecVote.getFinalList(4);

        vm.stopPrank();
    }

    // Test voting functionality
    function test_voteForCandidate() public candidate {
        // Register and nominate a candidate
        vm.startPrank(USER);
        test_DecVote.nominateCandidate(USER);

        // Attempt to vote before the election starts
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.voteForCandidate(USER);
        vm.stopPrank();

        // Finalize the candidate list and vote
        vm.startPrank(deployer);
        vm.warp(block.timestamp + (25 hours));
        test_DecVote.finalizeCandidateList();
        vm.stopPrank();

        // Candidate votes for themselves
        vm.startPrank(USER);
        test_DecVote.voteForCandidate(USER);

        // Ensure double voting throws an error
        vm.expectRevert(DecVotingSystem.AlreadyVotedError.selector);
        test_DecVote.voteForCandidate(USER);

        vm.stopPrank();

        address USER3 = makeAddr("User3");
        vm.startPrank(USER3);
        test_DecVote.registerAsVoter();
        vm.expectRevert(DecVotingSystem.NotFinalizedError.selector);
        test_DecVote.voteForCandidate(USER3);
        vm.stopPrank();

        vm.startPrank(USER2);
        test_DecVote.registerAsVoter();
        vm.warp(block.timestamp + (25 hours));
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.voteForCandidate(USER);
        vm.stopPrank();

        // Verify the vote count
        DecVotingSystem.Candidate memory candidateData = test_DecVote.getCandidateData(USER);
        assertEq(candidateData.voteCount, 1);
    }

    // Test publishing election results
    function test_publishElectionResult() public candidate {
        vm.startPrank(USER);
        test_DecVote.nominateCandidate(USER);
        vm.stopPrank();

        // Finalize the candidate list after the nomination period ends
        vm.startPrank(deployer);
        vm.warp(block.timestamp + 25 hours);
        test_DecVote.finalizeCandidateList();
        vm.stopPrank();

        // Another voter votes for USER
        vm.startPrank(USER2);
        test_DecVote.registerAsVoter();
        test_DecVote.voteForCandidate(USER);
        vm.stopPrank();

        // Publish the election result after the election end time
        vm.startPrank(deployer);
        vm.warp(block.timestamp + 25 hours);
        test_DecVote.publishElectionResult();
        vm.stopPrank();

        // Verify that USER is declared the winner
        assertEq(test_DecVote.s_winner(), USER);
    }

    // Test withdraw function
    function test_withdraw() public {
        address nonOwner = makeAddr("nonOwner");

        // Ensure non-owner cannot withdraw
        vm.startPrank(nonOwner);
        vm.expectRevert(DecVotingSystem.NotOwner.selector);
        test_DecVote.withdraw();
        vm.stopPrank();

        // Ensure owner can withdraw successfully
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.Withdrawn(deployer, test_DecVote.getBalance());
        test_DecVote.withdraw();
        vm.stopPrank();
    }

    // Test getter for voter data
    function test_getVoter() public voter {
        vm.startPrank(USER);
        address voterAddress = test_DecVote.getVotersAddress(0);
        assertEq(voterAddress, USER);

        vm.expectRevert(DecVotingSystem.IndexOutOfBoundsError.selector);
        test_DecVote.getVotersAddress(2);

        DecVotingSystem.Voter memory voterData = test_DecVote.getVoterData(voterAddress);
        assertEq(voterData.voterAddress, USER);
        assertFalse(voterData.hasNominated);
        assertFalse(voterData.hasVoted);
        vm.stopPrank();
    }

    function test_getCandidate() public candidate {
        vm.startPrank(USER);
        address candidateAddress = test_DecVote.getCandidateAddress(0);
        assertEq(candidateAddress, USER);

        vm.expectRevert(DecVotingSystem.IndexOutOfBoundsError.selector);
        test_DecVote.getCandidateAddress(2);

        DecVotingSystem.Candidate memory candidateData = test_DecVote.getCandidateData(candidateAddress);
        assertEq(candidateData.candidateName, NAME);
        assertEq(candidateData.candidateAddress, USER);
        assertEq(candidateData.voteCount, 0);
        assertEq(candidateData.nominationCount, 0);
        assertFalse(candidateData.isOfficialCandidate);
        vm.stopPrank();
    }
}
