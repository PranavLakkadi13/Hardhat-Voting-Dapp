// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FundVoting {

    // STRUCTS
    struct Contribution {
        uint256 Value;
        bool Contributed;
    }

    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool completed;
        uint noOfvoters;
        mapping(address => bool) voters;
    }

    // STATE VARIABLES 
    address private immutable i_owner;
    uint256 private immutable i_goal;
    uint256 private immutable i_minContribution;
    uint256 private immutable i_deadline;
    uint256 private s_raisedAmount;
    mapping(address => Contribution) private s_contributions;
    mapping(uint => Request) private s_requests;
    uint private s_numOfRequests;

    // Functions 

    constructor(uint256 _goal, uint256 _minContribution, uint256 _deadline) payable{
        i_owner = msg.sender;
        i_minContribution = _minContribution;
        i_goal = _goal;
        i_deadline = block.timestamp + _deadline;
    }
}