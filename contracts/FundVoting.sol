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
    error  FundVoting__InvalidReceipentAddressProvided();
    error  FundVoting__ValueShouldBeGreaterThanZero();
    error  FundVoting__DontHaveSufficientFunds();
    error  FundVoting__NoRequestsMade();
    error  FundVoting__InvalidProposal();
    error  FundVoting__InvalidRequestIDOfThatProposal();


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
 
    event VoteCasted(address indexed voter, VOTE indexed vote);

    event PaymentMade(uint256 indexed proposalID, uint256 indexed requestID);
    
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

    modifier IfValidProposalID(uint256 proposalID) {
        if (proposalID > proposalCount) {
            revert FundVoting__InvalidProposal();
        }
        _;
    }

    modifier IfValidRequestIDOfParticularProposal(uint256 proposalID, uint256 requestID) {
        Proposal storage currentProposal = proposals[proposalID];
        if (currentProposal.requestCount <= requestID) {
            revert FundVoting__InvalidRequestIDOfThatProposal();
        }

        _;
    }
    
    // FUNCTIONS 
    constructor(address SoulBoundToken1) payable {
        Token = SoulBoundToken(SoulBoundToken1);
    }

    /// @param _description The main Description of the proposal to be Created 
    /// @param _deadline The duration of the proposal to take in donations 
    /// @param _goal The Goal of the Campaign 
    function createProposal(string calldata _description , uint256 _deadline, uint256 _goal) external OnlyMember {
        if (_goal <= 0 ) {
            revert FundVoting__ValueShouldBeGreaterThanZero();
        }

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

    /// @param proposalID The Id of the Proposal the user wants to contribute to 
    function Contribute(uint256 proposalID) external payable 
    IfValidProposalID(proposalID)
    OnlyMember 
    IsActive(proposalID) {

        if (msg.value <= 0 ) {
            revert FundVoting__ValueShouldBeGreaterThanZero();
        }
        
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

    /// @param proposalID The Id of the Proposal the user wants to create a request 
    /// @param _recipient The address of the funds receiver 
    /// @param _description The reason to spend the funds 
    /// @param _value The amount value being transfered 
    function CreateRequest(uint256 proposalID, address _recipient, string calldata _description, uint256 _value) 
    external 
    IfValidProposalID(proposalID)
    OnlyOwner(proposalID)
    {
        if (_value <= 0 ) {
            revert FundVoting__ValueShouldBeGreaterThanZero();
        }

        if (_recipient == address(0)) {
            revert FundVoting__InvalidReceipentAddressProvided();
        }

        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[existingProposal.requestCount];

        if (_value > getRemainingBalance(proposalID)) {
            revert FundVoting__DontHaveSufficientFunds();
        }

        newRequest.receipient = _recipient;
        newRequest.description = _description;
        newRequest.valueRequestedToBeSpent = _value;
        newRequest.proposalID = proposalID;

        unchecked {
            existingProposal.requestCount++;
        }

        emit RequestCreated(proposalID, _recipient , _description, _value);
    }

    /// @param proposalID The Id of the Proposal the user wants to vote on 
    /// @param requestID The Id of the Request the user wants to vote on 
    /// @param vote The User vote 
    function VoteRequest(uint256 proposalID, uint256 requestID, VOTE vote) external 
    OnlyMember 
    IfValidProposalID(proposalID)
    IfValidRequestIDOfParticularProposal(proposalID,requestID)
    ActiveIfRequestNotFulfilled(proposalID,requestID) 
     {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[requestID];

        if (vote == VOTE.YES) {
            newRequest.voted[msg.sender] = VOTE.YES;
            unchecked {
                newRequest.voteCount++;
                newRequest.yesVotes++;
            }
            emit VoteCasted(msg.sender, VOTE.YES);
        }

        else {
            newRequest.voted[msg.sender] = VOTE.NO;
            unchecked {
                newRequest.voteCount++;
                newRequest.noVotes++;
            }
            emit VoteCasted(msg.sender, VOTE.NO);
        }

    }

    /// @param proposalID The Id of the Proposal the user wants to vote on 
    /// @param requestID The Id of the Request the user wants to vote on 
    /// @param vote The User vote To change to 
    function changeVoteOnRequest(uint256 proposalID, uint256 requestID, VOTE vote) 
    external 
    OnlyMember 
    IfValidProposalID(proposalID)
    IfValidRequestIDOfParticularProposal(proposalID,requestID)
    ActiveIfRequestNotFulfilled(proposalID,requestID) 
    {
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
            emit VoteCasted(msg.sender, VOTE.YES);
        }
        
        if (vote == VOTE.NO) {
            newRequest.noVotes++;
            newRequest.voted[msg.sender] == VOTE.NO;
            emit VoteCasted(msg.sender, VOTE.NO);
        }
    }


    /// @param proposalID The proposal ID 
    /// @param requestID The Request ID of a particular proposal user want to fulfill
    function makePayment(uint256 proposalID, uint256 requestID) 
    external 
    OnlyOwner(proposalID) 
    IfValidProposalID(proposalID)
    IfValidRequestIDOfParticularProposal(proposalID,requestID)
    ActiveIfRequestNotFulfilled(proposalID,requestID) 
    nonReentrant 
    {
        Proposal storage existingProposal = proposals[proposalID];
        
        Request storage newRequest = existingProposal.requests[requestID];

        if (newRequest.voteCount / 2 > newRequest.yesVotes ) {
            revert FundVoting__YouDidntReceiveEnoughVotesToPassRequest();
        }

        uint256 transferAMount = newRequest.valueRequestedToBeSpent;
        newRequest.valueRequestedToBeSpent = 0;
        newRequest.completed = true;
        existingProposal.raisedAmount -= transferAMount;

        (bool success, ) = newRequest.receipient.call{value : transferAMount}("");

        if (!success) {
            revert FundVoting__TransactionFailed();
        }

        emit PaymentMade(proposalID, requestID);
    }

    
    // GETTER FUNCTION 

    /// @param proposalID The proposal ID whose details user wants to view 
    function getTotalAMountRequested(uint256 proposalID) public view 
    IfValidProposalID(proposalID) 
    returns (uint256 x) {
        Proposal storage existingProposal = proposals[proposalID];
    
        uint256 y = existingProposal.requestCount;

        if (y == 0 ) {
            x = existingProposal.raisedAmount;
        }

        for (uint i = 0; i < y; ) {

            Request storage newRequest = existingProposal.requests[i];
            x += newRequest.valueRequestedToBeSpent;

            unchecked {
                i++;
            }
        }
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getRemainingBalance(uint256 proposalID) IfValidProposalID(proposalID) public 
    view returns (uint256 x) {
        Proposal storage existingProposal = proposals[proposalID];

        x = existingProposal.raisedAmount - getTotalAMountRequested(proposalID);
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getProposalDescription(uint256 proposalID) IfValidProposalID(proposalID) 
    public view returns (string memory) {
        return proposals[proposalID].mainDescription;
    }

    /// @notice Returns the proposal count 
    function getProposalCount() public view returns (uint256) {
        return proposalCount;
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getProposalOwner(uint256 proposalID) IfValidProposalID(proposalID) public view returns (address) {
        return proposals[proposalID].ownerOfProposal;
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getProposalDeadline(uint256 proposalID) IfValidProposalID(proposalID) public view returns (uint256) {
        return proposals[proposalID].deadline;
    }

    function getProposalGoal(uint256 proposalID) IfValidProposalID(proposalID) public view returns (uint256) {
        return proposals[proposalID].goal;
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    /// @param contributor The deatils of the contribution of the contributor of a particular proposal 
    function getProposalContributor_Contribution(uint256 proposalID, address contributor) IfValidProposalID(proposalID) 
    public view returns (uint256) {
        return proposals[proposalID].contributors[contributor];
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getProposalContributionCounter(uint256 proposalID) IfValidProposalID(proposalID) 
    public view returns (uint256) {
        return proposals[proposalID].numOfContributors;
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    function getProposalRequestCount(uint256 proposalID) IfValidProposalID(proposalID) 
    public view returns (uint256) {
        return proposals[proposalID].requestCount;
    }

    /// @param proposalID The proposal ID whose details user wants to view 
    /// @param requestId The requestId of the proposal whose receipient address you want 
    function getProposalRequestRecepient(uint256 proposalID,uint256 requestId) IfValidProposalID(proposalID) 
    IfValidRequestIDOfParticularProposal(proposalID,requestId) 
    public view returns (address) {
        return proposals[proposalID].requests[requestId].receipient;
    }

    // function 

}