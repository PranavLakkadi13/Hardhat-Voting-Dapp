// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SoulBoundToken.sol";

contract FundVoting {

    // ERRORS
    error  FundVoting__OnlyMemberAllowed();
    error  FundVoting__OnlyOwnerCanCallThis();
    error FundVoting__TimeToContributeExpired();

    // STRUCTS
    struct Proposal {
        address ownerOfProposal;
        uint256 deadline;
        uint256 goal;
        uint256 raisedAmount;
        string mainDescription;
        mapping(address => uint256) contributors;
        uint256 numOfContributors;
        uint256 requestCount;
        mapping(uint256 => Request) requests;
    }

    struct Request {
        address receipient;
        string description;
        uint256 valueRequestedToBeSpent;
        bool completed;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 proposalID;
        uint256 requestCount; 
    }


    // STATE VARIABLES 
    SoulBoundToken private Token;

    uint256 private proposalCount;

    mapping(uint256 => Proposal) private proposals;


    // EVENTS 
    event ProposalCreated(string indexed description, uint256 indexed goal , uint256 indexed deadline);

    event Contributed(address indexed contributee, uint256 indexed contribution);
 
    
    // MODIFIERS
    modifier OnlyMember() {
        if (Token.balanceOf(msg.sender) == 0) {
            revert FundVoting__OnlyMemberAllowed();
        }
        _;
    }

    modifier IsActive(uint256 ID) {
        if (proposals[ID].deadline < block.timestamp) {
            revert FundVoting__TimeToContributeExpired();
        }
        _;
    }

    modifier OnlyOwner(uint256 ID) {
        if (proposals[ID].ownerOfProposal != msg.sender) {
            revert FundVoting__OnlyOwnerCanCallThis();
        }
        _;
    }
    
    // FUNCTIONS 
    constructor(address SoulBoundToken1) payable {
        Token = SoulBoundToken(SoulBoundToken1);
    }

    function createProposal(string calldata _description , uint256 _deadline, uint256 _goal) external OnlyMember {
        Proposal storage proposal = proposals[proposalCount];

        proposal.deadline = block.timestamp + _deadline;
        proposal.ownerOfProposal = msg.sender;
        proposal.goal = _goal;
        proposal.mainDescription = _description;

        unchecked {
            proposalCount++;
        }

        emit ProposalCreated(_description, _goal , _deadline);
    }

    function Contribute(uint256 proposalID) external payable OnlyMember IsActive(proposalID) {
        
        Proposal storage proposal = proposals[proposalID];

        if (proposal.contributors[msg.sender] == 0) {
            proposal.numOfContributors++;
        }

        unchecked {
            proposal.contributors[msg.sender] += msg.value;
            proposal.raisedAmount += msg.value;
        }

        emit Contributed(msg.sender, msg.value);
    }

    function CreateRequest(uint256 proposalID, address _recipient, string calldata _description, uint256 _value) external OnlyOwner(proposalID){
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[existingProposal.requestCount];
    }

}