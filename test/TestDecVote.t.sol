// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployVotingSystem} from "../script/DeployDecVote.s.sol";
import {DecVotingSystem} from "../src/DecVote.sol";

contract TestVotingSystem is Test {
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    string NAME = "Developer1";
    uint256 constant SEND_VALUE = 0.01 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    bytes constant RANDOM_DATA = "Random Data";

    address deployer;
    DecVotingSystem test_DecVote;

    function setUp() external {
        DeployVotingSystem deploy = new DeployVotingSystem();
        test_DecVote = deploy.run();
        deployer = msg.sender;

        vm.deal(USER, STARTING_BALANCE);
    }

    function test_constructor() public {
        uint256 _registrationFee = 0.01 ether;
        uint256 _nominationEndTime = 2;
        uint256 _electionEndTime = 3;

        DecVotingSystem newDecVote = new DecVotingSystem(_registrationFee, _nominationEndTime, _electionEndTime);

        assertEq(newDecVote.i_owner(), address(this));
        assertEq(newDecVote.i_registration_fee(), _registrationFee);
        assertEq(newDecVote.i_nomination_endTime(), block.timestamp + (_nominationEndTime * 1 hours));
        assertEq(newDecVote.i_election_endTime(), block.timestamp + (_electionEndTime * 1 hours));
    }

    function test_onlyOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        assertNotEq(nonOwner, test_DecVote.i_owner());
        vm.expectRevert(DecVotingSystem.NotOwner.selector);
        test_DecVote.finalizeCandidateList();

        vm.startPrank(deployer);
        assertEq(deployer, test_DecVote.i_owner());
        vm.warp(block.timestamp + (25 hours));
        test_DecVote.finalizeCandidateList();
        vm.stopPrank();
    }

    // function test_onlyVoter() public {
    //     address nonVoter = makeAddr("nonVoter");
    //     vm.deal(nonVoter, STARTING_BALANCE);

    //     vm.startPrank(nonVoter);
    //     address listAddress = test_DecVote.getVoterData(nonVoter).voterAddress;
    //     assertNotEq(listAddress, nonVoter);
    //     vm.expectRevert(DecVotingSystem.NotRegisteredError.selector);
    //     test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);
    //     vm.stopPrank();

    //     vm.startPrank(nonVoter);
    //     test_DecVote.registerAsVoter();
    //     address listAddr = test_DecVote.getVoterData(nonVoter).voterAddress;
    //     assertEq(listAddr, nonVoter);
    //     test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);
    //     vm.stopPrank();
    // }

    modifier voter() {
        vm.prank(USER);
        test_DecVote.registerAsVoter();
        _;
    }

    modifier candidate() {
        vm.startPrank(USER);
        test_DecVote.registerAsVoter();
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);
        vm.stopPrank();
        _;
    }

    function test_registerAsVoter() public {
        vm.startPrank(USER);

        address checkAddress = test_DecVote.getVoterData(USER).voterAddress;
        assertNotEq(USER, checkAddress);

        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.VoterRegistered(USER);
        test_DecVote.registerAsVoter();

        vm.expectRevert(DecVotingSystem.AlreadyRegisteredError.selector);
        test_DecVote.registerAsVoter();

        vm.stopPrank();
    }

    function test_registerAsCandidate() public voter {
        vm.startPrank(USER);

        vm.expectRevert(DecVotingSystem.InputError.selector);
        test_DecVote.registerAsCandidate{value: 0}(NAME);

        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.CandidateRegistered(NAME, USER);
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);

        vm.expectRevert(DecVotingSystem.AlreadyRegisteredError.selector);
        test_DecVote.registerAsCandidate{value: SEND_VALUE}(NAME);

        vm.stopPrank();
    }

    function test_nominateCandidate() public candidate {
        vm.startPrank(USER);

        // test_DecVote.registerAsVoter();
        test_DecVote.nominateCandidate(USER);

        vm.expectRevert(DecVotingSystem.AlreadyNominatedError.selector);
        test_DecVote.nominateCandidate(USER);

        vm.stopPrank();

        vm.startPrank(USER2);

        test_DecVote.registerAsVoter();

        vm.expectRevert(DecVotingSystem.NotRegisteredError.selector);
        test_DecVote.nominateCandidate(USER2);

        vm.warp(block.timestamp + 25 hours);
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.nominateCandidate(USER);

        vm.stopPrank();
    }

    function test_finalizeCandidateList() public {
        address[3] memory candidates;
        candidates[0] = makeAddr("candidate0");
        candidates[1] = makeAddr("candidate1");
        candidates[2] = makeAddr("candidate2");

        string[3] memory candidateNames;
        candidateNames[0] = "Candidate0";
        candidateNames[1] = "Candidate1";
        candidateNames[2] = "Candidate2";

        for (uint256 i = 0; i < candidates.length; i++) {
            vm.deal(candidates[i], STARTING_BALANCE);
            vm.startPrank(candidates[i]);
            test_DecVote.registerAsVoter();
            test_DecVote.registerAsCandidate{value: SEND_VALUE}(candidateNames[i]);
            test_DecVote.nominateCandidate(candidates[i]);
            vm.stopPrank();
        }

        vm.startPrank(deployer);
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.finalizeCandidateList();

        vm.warp(block.timestamp + (25 hours));
        test_DecVote.finalizeCandidateList();
        vm.stopPrank();

        // Check that USER is in the finalized list
        address finalizedCandidate = test_DecVote.getFinalList(0);
        assertEq(finalizedCandidate, candidates[0]);

        vm.expectRevert(DecVotingSystem.IndexOutOfBoundsError.selector);
        test_DecVote.getFinalList(4);
    }

    function test_voteForCandidate() public candidate {
        // Register and nominate a candidate
        vm.startPrank(USER);
        test_DecVote.nominateCandidate(USER);

        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.voteForCandidate(USER);

        vm.stopPrank();

        // Finalize the candidate list
        vm.startPrank(deployer);
        vm.warp(block.timestamp + (25 hours));
        test_DecVote.finalizeCandidateList();
        vm.stopPrank();

        // Vote for the candidate
        // Candidate vote for himself
        vm.startPrank(USER);
        test_DecVote.voteForCandidate(USER);

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

    function test_publishElectionResult() public candidate {
        vm.startPrank(USER);
        test_DecVote.nominateCandidate(USER);

        vm.stopPrank();

        vm.startPrank(deployer);
        // vm.warp(block.timestamp + (2 hours));
        // assertTrue(block.timestamp < test_DecVote.i_election_endTime());
        vm.expectRevert(DecVotingSystem.TimeError.selector);
        test_DecVote.finalizeCandidateList();

        vm.warp(block.timestamp + 25 hours);
        test_DecVote.finalizeCandidateList();

        vm.stopPrank();

        vm.startPrank(USER2);
        test_DecVote.registerAsVoter();
        test_DecVote.voteForCandidate(USER);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.warp(block.timestamp + 25 hours);
        test_DecVote.publishElectionResult();
        vm.stopPrank();

        // Verify the winner
        assertEq(test_DecVote.s_winner(), USER);
    }

    function test_withdraw() public candidate {
        address nonOwner = makeAddr("nonOwner");
        vm.startPrank(nonOwner);
        vm.expectRevert(DecVotingSystem.NotOwner.selector);
        test_DecVote.withdraw();
        vm.stopPrank();

        vm.startPrank(deployer);
        assertEq(deployer, test_DecVote.i_owner());
        vm.expectEmit(true, true, true, true);
        emit DecVotingSystem.Withdrawn(deployer, test_DecVote.getBalance());
        test_DecVote.withdraw();
        vm.stopPrank();
    }

    // Getters

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
