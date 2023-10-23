// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SoulBoundToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FundVoting is ReentrancyGuard {

    // ERRORS
    error  FundVoting__OnlyMemberAllowed();
    error  FundVoting__OnlyOwnerCanCallThis();
    error  FundVoting__TimeToContributeExpired();
    error  FundVoting__RequestHasAlreadyBeenFulfilled();
    error  FundVoting__YouDidntReceiveEnoughVotesToPassRequest();
    error  FundVoting__TransactionFailed();


    // ENUMS 
    enum VOTE {YES,NO}

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
        uint256 proposalID;
        address receipient;
        string description;
        uint256 valueRequestedToBeSpent;
        bool completed;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 voteCount;
        mapping(address => VOTE) voted;
    }


    // STATE VARIABLES 
    SoulBoundToken private Token;

    uint256 private proposalCount;

    mapping(uint256 => Proposal) private proposals;


    // EVENTS 
    event ProposalCreated(string indexed description, uint256 indexed goal , uint256 indexed deadline);

    event Contributed(address indexed contributee, uint256 indexed contribution);

    event RequestCreated(uint256 indexed proposalID, address indexed recipient, string indexed description, uint256 value);
 
    
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

    modifier ActiveIfRequestNotFulfilled(uint256 proposalID,uint256 requestID) {
        Proposal storage currentProposal = proposals[proposalID];

        Request storage thisRequest = currentProposal.requests[requestID];

        if (thisRequest.completed) {
            revert FundVoting__RequestHasAlreadyBeenFulfilled();
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

    function CreateRequest(uint256 proposalID, address _recipient, string calldata _description, uint256 _value) 
    external 
    OnlyOwner(proposalID)
    {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[existingProposal.requestCount];

        newRequest.receipient = _recipient;
        newRequest.description = _description;
        newRequest.valueRequestedToBeSpent = _value;
        newRequest.proposalID = proposalID;

        unchecked {
            existingProposal.requestCount++;
        }

        emit RequestCreated(proposalID, _recipient , _description, _value);
    }

    function VoteRequest(uint256 proposalID, uint256 requestID, VOTE vote) external 
    OnlyMember 
    ActiveIfRequestNotFulfilled(proposalID,requestID) {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[requestID];

        if (vote == VOTE.YES) {
            newRequest.voted[msg.sender] = VOTE.YES;
            unchecked {
                newRequest.voteCount++;
                newRequest.yesVotes++;
            }
        }

        else {
            newRequest.voted[msg.sender] = VOTE.NO;
            unchecked {
                newRequest.voteCount++;
                newRequest.noVotes++;
            }
        }
    }

    function changeVoteOnRequest(uint256 proposalID, uint256 requestID, VOTE vote) 
    external 
    OnlyMember 
    ActiveIfRequestNotFulfilled(proposalID,requestID) {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[requestID];

        if (newRequest.voted[msg.sender] == VOTE.YES) {
            newRequest.yesVotes--;
        }
        if (newRequest.voted[msg.sender] == VOTE.NO) {
            newRequest.noVotes--;
        }

        if (vote == VOTE.YES) {
            newRequest.yesVotes++;
            newRequest.voted[msg.sender] = VOTE.YES;
        }
        
        if (vote == VOTE.NO) {
            newRequest.noVotes++;
            newRequest.voted[msg.sender] == VOTE.NO;
        }
    }

    function makePayment(uint256 proposalID, uint256 requestID) 
    external 
    OnlyOwner(proposalID) 
    ActiveIfRequestNotFulfilled(proposalID,requestID) 
    nonReentrant {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[requestID];

        if (newRequest.voteCount / 2 > newRequest.yesVotes ) {
            revert FundVoting__YouDidntReceiveEnoughVotesToPassRequest();
        }

        uint256 transferAMount = newRequest.valueRequestedToBeSpent;
        newRequest.valueRequestedToBeSpent = 0;
        newRequest.completed = true;

        (bool success, ) = newRequest.receipient.call{value : transferAMount}("");

        if (!success) {
            revert FundVoting__TransactionFailed();
        }
    }

}