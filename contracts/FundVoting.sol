// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SoulBoundToken.sol";

contract FundVoting {

    // ERRORS
    error FundVoting__NotOwnerCalled();
    error FundVoting__DeadlinePassed();
    error FundVoting__NotMemberOfDAO();
    error FundVoting__InvalidSpendingRequest();
    error FundVoting__ZeroVAlueNotAllowed();

    // STRUCTS
    struct Contribution {
        uint256 Value;
        bool Contributed;
    }

    struct Request {
        string description;
        address recipient;
        uint value;
        bool completed;
        uint noOfvoters;
        mapping(address => bool) voters;
    }

    // EVENTS 
    event CreatedRequested(string indexed Description, address indexed receiver, uint256 indexed value);

    // STATE VARIABLES 
    string private s_description;
    address private immutable i_owner;
    uint256 private immutable i_goal;
    uint256 private immutable i_deadline;
    uint256 private s_raisedAmount;
    uint256 private s_requestCounter;
    mapping(address => Contribution) private s_contributions;
    mapping(uint256 => Request) private s_requests;
    uint256 private s_numOfRequests;

    SoulBoundToken private immutable s_member;

    // Functions 
    modifier OnlyAdmin() {
        if (msg.sender != i_owner) {
            revert FundVoting__NotOwnerCalled();
        }
        _;
    }

    modifier IsActive() {
        if (block.timestamp > i_deadline) {
            revert FundVoting__DeadlinePassed();
        }
        _;
    }

    modifier IsMember() {
        if (s_member.balanceOf(msg.sender) > 0) {
            revert FundVoting__NotMemberOfDAO();
        }
        _;
    }

    constructor(uint256 _goal, uint256 _deadline, address TokenAddress, string memory _description) payable{
        i_owner = msg.sender;
        i_goal = _goal;
        i_deadline = block.timestamp + _deadline;
        s_member = SoulBoundToken(TokenAddress);
        s_description = _description;
    }

    function CreateRequest(string calldata _description, uint256 _value, address receiver) external IsMember {
        if (_value >= address(this).balance) {
            revert FundVoting__InvalidSpendingRequest();
        }

        Request storage newRequest = s_requests[s_requestCounter];

        newRequest.description = _description;
        newRequest.recipient = receiver;
        newRequest.value = _value;

        emit CreatedRequested(_description, receiver, _value);
    }

    function Contribute() external payable IsMember IsActive{
        if (msg.value == 0) {
            revert FundVoting__ZeroVAlueNotAllowed();
        }
        
        
    }

}