// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "./SoulBoundToken.sol";

contract voting {

    error voting__OnlyPeopleWithSoulBoundTokenCanParticipate();
    error voting__TheTimeToVoteHasExpired();
    error voting__AlreadyVotedUse_updateVote();
    error voting__DeadlineShouldBeGreaterThan0();
    error voting__DescriptionCantBeEmpty();
    error voting__InvalidProposalId();
    error voting__DontVoteIfYouWishToAbstain();

    event ProposalCreated(string indexed Description,uint256 indexed proposalId, address indexed proposer);
    event Voted(uint256 indexed s_proposalCount, address indexed voter);

    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        mapping(address => bool) voters;
        mapping(address => Vote) voteTracker;
    }

    enum Vote{Abstain,Yes,No}

    uint256 private s_proposalCount;
    mapping(uint256 => Proposal) private s_proposalMapping;
    SoulBoundToken private s_members;

    constructor(address _members) payable {
        s_members = SoulBoundToken(_members);
    }

    modifier MembersOnly() {
        if (s_members.balanceOf(msg.sender) == 0) {
            revert voting__OnlyPeopleWithSoulBoundTokenCanParticipate();
        }
        _;
    }

    modifier InactiveProposal(uint256 proposalID) {
        if (s_proposalMapping[proposalID].deadline < block.timestamp) {
            revert voting__TheTimeToVoteHasExpired();
        }
        _;
    }

    function createProposal(string calldata _description, uint256 _deadline) external MembersOnly {
        if (_deadline <= 0) {
            revert voting__DeadlineShouldBeGreaterThan0();
        }
        
        if (bytes(_description).length <= 0) {
            revert voting__DescriptionCantBeEmpty();
        }

        Proposal storage newProposal = s_proposalMapping[s_proposalCount];
        newProposal.description = _description;
        newProposal.deadline = block.timestamp + _deadline;

        s_proposalCount++;

        emit ProposalCreated(_description, s_proposalCount, msg.sender);
    }

    function casteVote(uint256 id,Vote vote) external MembersOnly InactiveProposal(id) {

        if (s_proposalCount < id) {
            revert voting__InvalidProposalId();
        }

        if (vote == Vote.Abstain) {
            revert voting__DontVoteIfYouWishToAbstain();
        }

        Proposal storage proposal = s_proposalMapping[id];

        if (proposal.voters[msg.sender]) {
            revert voting__AlreadyVotedUse_updateVote();
        }
        
        if (vote == Vote.Yes) {
            proposal.yesVotes++;
            proposal.voters[msg.sender] = true;
            proposal.voteTracker[msg.sender] = Vote.Yes;
        }
        else {
            proposal.noVotes++;
            proposal.voters[msg.sender] = true;
            proposal.voteTracker[msg.sender] = Vote.No;
        }
        proposal.voters[msg.sender] = true;

        emit Voted(s_proposalCount, msg.sender);
    }

    function updateVote(uint256 id) external InactiveProposal(id){

        if (s_proposalCount < id) {
            revert voting__InvalidProposalId();
        }

        Proposal storage proposal = s_proposalMapping[id];

        if (proposal.voters[msg.sender]) {
            if (proposal.voteTracker[msg.sender] == Vote.Yes) {
                proposal.yesVotes--;
                proposal.noVotes++;
                proposal.voteTracker[msg.sender] = Vote.No;
            }
            else {
                proposal.yesVotes++;
                proposal.noVotes--;
                proposal.voteTracker[msg.sender] = Vote.Yes;
            }
        }
    }

    function getProposalDescription(uint256 id) external view returns (string memory) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.description;
    }

    function getProposalYesVotes(uint256 id) external view returns (uint256) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.yesVotes;
    }

    function getProposalNoVotes(uint256 id) external view returns (uint256) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.noVotes;
    }

    function getProposaldeadline(uint256 id) external view returns (uint256) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.deadline;
    }

    function getProposaldIsVoter(uint256 id) external view returns (bool) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.voters[msg.sender];
    }

    function getProposalVoterVote(uint256 id) external view returns(Vote) {
        Proposal storage proposal = s_proposalMapping[id];
        return proposal.voteTracker[msg.sender];
    }

    function getProposalCount() external view returns (uint256) {
        return s_proposalCount;
    }

}