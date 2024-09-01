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
    error NotOwner();
    error WithdrawError();
    error InputError();
    error TimeError();
    error NotRegisteredError();
    error NotFinalizedError();
    error AlreadyRegisteredError();
    error AlreadyNominatedError();
    error AlreadyVotedError();
    error IndexOutOfBoundsError();

    // =======================================
    //           CONSTANTS & IMMUTABLES
    // =======================================
    address private immutable i_owner;
    uint256 public immutable i_registration_fee;
    uint256 private constant TOLERANCE = 2 wei;
    uint256 private immutable i_nomination_endTime;
    uint256 private immutable i_election_endTime;

    // =======================================
    //           STATE VARIABLES
    // =======================================
    uint256 public s_nominationThreshold;
    address public s_winner;
    address[] private s_voterList;
    address[] private s_candidateList;
    address[] private finalList;

    mapping(address => Voter) private s_voterData;
    mapping(address => Candidate) private s_candidateData;

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
    event Withdrawn(address indexed to, uint256 amount);

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
            revert InputError();
        }
        i_owner = msg.sender;
        i_registration_fee = _registrationFee;
        i_nomination_endTime = block.timestamp + (_nominationEndTime * 1 hours);
        i_election_endTime = block.timestamp + (_electionEndTime * 1 hours);
    }
    /**
     * @dev Modifier to restrict access to the owner
     */

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
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

        // Update nomination threshold if the nomination period is still active
        if (block.timestamp < i_nomination_endTime) {
            updateNominationThreshold();
        }
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
    function registerAsCandidate(string memory name) public payable onlyVoter {
        if (s_candidateData[msg.sender].candidateAddress == msg.sender) {
            revert AlreadyRegisteredError();
        } else if (msg.value < i_registration_fee - TOLERANCE || msg.value > i_registration_fee + TOLERANCE) {
            revert InputError();
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
        if (block.timestamp > i_nomination_endTime) {
            revert TimeError();
        } else if (s_voterData[msg.sender].hasNominated) {
            revert AlreadyNominatedError();
        } else if (s_candidateData[candidate].candidateAddress != candidate) {
            revert NotRegisteredError();
        }
        s_voterData[msg.sender].hasNominated = true;
        s_candidateData[candidate].nominationCount++;
    }

    /**
     * @dev Finalizes the candidate list by filtering out candidates who do not meet the nomination threshold.
     */
    function finalizeCandidateList() public onlyVoter {
        if (block.timestamp <= i_nomination_endTime) {
            revert TimeError();
        } else if (finalList.length == 0) {
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
    }

    /**
     * @dev Allows a voter to vote for a candidate.
     * @param candidate The address of the candidate being voted for.
     */
    function voteForCandidate(address candidate) public onlyVoter {
        if (block.timestamp < i_nomination_endTime || block.timestamp > i_election_endTime) {
            revert TimeError();
        } else if (s_voterData[msg.sender].hasVoted) {
            revert AlreadyVotedError();
        } else if (!s_candidateData[candidate].isOfficialCandidate) {
            revert NotFinalizedError();
        }

        s_voterData[msg.sender].hasVoted = true;
        s_candidateData[candidate].voteCount++;

        emit VoterVoted(msg.sender, candidate);
    }

    /**
     * @dev Retrieves the election result by determining the candidate with the highest vote count.
     */
    function publishElectionResult() public {
        if (block.timestamp <= i_election_endTime) {
            revert TimeError();
        } else if (s_winner == address(0)) {
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
    }

    function wthdraw() public onlyOwner {
        uint256 balance = address(this).balance; // Store the balance before modifying state

        // Transfer the contract's balance to the owner
        (bool callSuccess,) = payable(msg.sender).call{value: balance}("");
        if (!callSuccess) {
            revert WithdrawError();
        }

        emit Withdrawn(msg.sender, balance); // Emit a withdrawn event
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
        if (index >= s_voterList.length) {
            revert IndexOutOfBoundsError();
        }
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
        if (index >= s_candidateList.length) {
            revert IndexOutOfBoundsError();
        }
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

    /**
     * @dev Returns the address of a finalized candidate by index.
     * @param index The index of the finalized candidate in the list.
     * @return The address of the finalized candidate.
     */
    function getFinalList(uint256 index) public view returns (address) {
        if (index >= finalList.length) {
            revert IndexOutOfBoundsError();
        }
        return finalList[index];
    }
}
