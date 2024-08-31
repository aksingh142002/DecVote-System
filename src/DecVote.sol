// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Voting System
 * @notice This contract handles candidate and voter registration, voting mechanism,
 *         vote counting, and result announcement, with event emission, security,
 *         and access control.
 */
contract DecVotingSystem {
    // =======================================
    //           CUSTOM ERRORS
    // =======================================
    error AlreadyRegisteredError();
    error NotRegisteredError();
    error InsufficientFeeError();
    error AlreadyNominatedError();
    error AlreadyVotedError();

    // =======================================
    //           CONSTANTS & IMMUTABLES
    // =======================================
    uint256 public immutable i_registration_fee;
    uint256 public constant TOLERANCE = 2 wei;
    uint256 public immutable i_nomination_endTime;
    uint256 public immutable i_election_endTime;

    // =======================================
    //           STATE VARIABLES
    // =======================================
    uint256 public s_nominationThreshold;
    address public s_winner;
    address[] public s_voterList;
    address[] public s_candidateList;
    address[] public finalList;

    mapping(address => Voter) public s_voterData;
    mapping(address => Candidate) public s_candidateData;

    // =======================================
    //           STRUCTS
    // =======================================
    struct Voter {
        address voterAddress;
        bool hasVoted;
        bool hasNominated;
    }

    struct Candidate {
        string candidateName;
        address candidateAddress;
        uint256 voteCount;
        uint256 nominationCount;
        bool isOfficialCandidate;
    }

    // =======================================
    //           EVENTS
    // =======================================
    event VoterRegistered(address indexed voter);
    event VoterVoted(address indexed voter, address indexed candidate);
    event CandidateRegistered(string name, address indexed candidate);
    event CandidateFinalized(address[] finalizedCandidates);

    // =======================================
    //           CONSTRUCTOR & MODIFIERS
    // =======================================

    /**
     * @dev Initializes the contract with registration fee, nomination end time, and election end time.
     * @param _registrationFee The fee required to register as a candidate.
     * @param _nominationEndTime Duration in hours after which nominations will end.
     * @param _electionEndTime Duration in hours after which the election will end.
     */
    constructor(uint256 _registrationFee, uint256 _nominationEndTime, uint256 _electionEndTime) {
        if (_registrationFee == 0 || _nominationEndTime == 0 || _electionEndTime <= _nominationEndTime) {
            revert InsufficientFeeError();
        }
        i_registration_fee = _registrationFee;
        i_nomination_endTime = block.timestamp + (_nominationEndTime * 1 hours);
        i_election_endTime = block.timestamp + (_electionEndTime * 1 hours);
    }

    /**
     * @dev Ensures that only registered voters can call certain functions.
     */
    modifier onlyVoter() {
        if (s_voterData[msg.sender].voterAddress != msg.sender) {
            revert NotRegisteredError();
        }
        _;
    }

    // =======================================
    //           FUNCTIONS
    // =======================================

    /**
     * @dev Registers a new voter.
     */
    function registerAsVoter() public {
        if (s_voterData[msg.sender].voterAddress == msg.sender) {
            revert AlreadyRegisteredError();
        }
        s_voterData[msg.sender] = Voter({voterAddress: msg.sender, hasVoted: false, hasNominated: false});
        s_voterList.push(msg.sender);

        updateNominationThreshold();
        emit VoterRegistered(msg.sender);
    }

    /**
     * @dev Updates the nomination threshold dynamically based on the number of registered voters.
     */
    function updateNominationThreshold() internal {
        s_nominationThreshold = s_voterList.length / 5;
    }

    /**
     * @dev Registers a new candidate. The candidate must be a registered voter.
     * @param name The name of the candidate.
     */
    function registerAsCandiate(string memory name) public payable onlyVoter {
        if (s_candidateData[msg.sender].candidateAddress == msg.sender) {
            revert AlreadyRegisteredError();
        } else if (msg.value < i_registration_fee - TOLERANCE || msg.value > i_registration_fee + TOLERANCE) {
            revert InsufficientFeeError();
        }
        s_candidateData[msg.sender] = Candidate({
            candidateName: name,
            candidateAddress: msg.sender,
            voteCount: 0,
            nominationCount: 0,
            isOfficialCandidate: false
        });
        s_candidateList.push(msg.sender);

        emit CandidateRegistered(name, msg.sender);
    }

    /**
     * @dev Allows a voter to nominate a candidate.
     * @param candidate The address of the candidate being nominated.
     */
    function nominateCandidate(address candidate) public onlyVoter {
        if (s_voterData[msg.sender].hasNominated) {
            revert AlreadyNominatedError();
        } else if (s_candidateData[candidate].candidateAddress != candidate) {
            revert NotRegisteredError();
        }
        s_voterData[msg.sender].hasNominated = true;
        s_candidateData[candidate].nominationCount++;
    }

    /**
     * @dev Finalizes the candidate list by filtering out candidates who do not meet the nomination threshold.
     * @return The list of candidates who are officially nominated.
     */
    function finalizeCandidateList() public onlyVoter returns (address[] memory) {
        if (finalList.length == 0) {
            require(block.timestamp > i_nomination_endTime, "Nomination time has not ended.");

            uint256 listLength = s_candidateList.length;
            uint256 nominationThreshold = s_nominationThreshold;

            address[] memory tempFinalList = new address[](listLength); // Temporary array to store qualified candidates
            uint256 tempFinalListLength = 0;

            for (uint256 i = 0; i < listLength; i++) {
                address candidateAddress = s_candidateList[i];
                Candidate storage candidate = s_candidateData[candidateAddress];

                if (candidate.nominationCount >= nominationThreshold) {
                    candidate.isOfficialCandidate = true;
                    tempFinalList[tempFinalListLength] = candidateAddress;
                    tempFinalListLength++;
                }
            }

            // Resize finalList to the number of qualified candidates
            finalList = new address[](tempFinalListLength);
            for (uint256 j = 0; j < tempFinalListLength; j++) {
                finalList[j] = tempFinalList[j];
            }

            emit CandidateFinalized(finalList);
        }
        return finalList;
    }

    /**
     * @dev Allows a voter to vote for a candidate.
     * @param candidate The address of the candidate being voted for.
     */
    function voteForCandidate(address candidate) public onlyVoter {
        require(block.timestamp < i_election_endTime, "Election time ended");
        if (s_voterData[msg.sender].hasVoted) {
            revert AlreadyVotedError();
        }
        s_voterData[msg.sender].hasVoted = true;
        s_candidateData[candidate].voteCount++;

        emit VoterVoted(msg.sender, candidate);
    }

    /**
     * @dev Retrieves the election result by determining the candidate with the highest vote count.
     * @return The address of the winning candidate.
     */
    function getElectionResult() public returns (address) {
        require(block.timestamp > i_election_endTime, "Election time not ended");

        if (s_winner == address(0)) {
            address temp;
            uint256 highestVoteCount = 0;
            uint256 listLength = finalList.length;

            for (uint256 i = 0; i < listLength; i++) {
                address candidate = finalList[i];
                uint256 candidateVotes = s_candidateData[candidate].voteCount;

                if (candidateVotes > highestVoteCount) {
                    highestVoteCount = candidateVotes;
                    temp = candidate;
                }
            }
            s_winner = temp;
        }
        return s_winner;
    }

    // =======================================
    //           ADDITIONAL GETTERS
    // =======================================

    /**
     * @dev Returns the address of a voter by index.
     * @param index The index of the voter in the list.
     * @return The address of the voter.
     */
    function getVotersAddress(uint256 index) public view returns (address) {
        return s_voterList[index];
    }

    /**
     * @dev Returns the data of a voter.
     * @param _vAddress The address of the voter.
     * @return The Voter struct containing the voter's data.
     */
    function getVoterData(address _vAddress) public view returns (Voter memory) {
        return s_voterData[_vAddress];
    }

    /**
     * @dev Returns the address of a candidate by index.
     * @param index The index of the candidate in the list.
     * @return The address of the candidate.
     */
    function getCandidateAddress(uint256 index) public view returns (address) {
        return s_candidateList[index];
    }

    /**
     * @dev Returns the data of a candidate.
     * @param _cAddress The address of the candidate.
     * @return The Candidate struct containing the candidate's data.
     */
    function getCandidateData(address _cAddress) public view returns (Candidate memory) {
        return s_candidateData[_cAddress];
    }
}
