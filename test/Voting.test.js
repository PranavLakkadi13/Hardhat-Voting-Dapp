const { assert, expect } = require("chai");
const { deployments, getNamedAccounts, ethers, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const {time} = require("@nomicfoundation/hardhat-network-helpers");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Voting Test", () => {
    let VotingContract;
    let SoulBound;
    let deployer;
    let accounts;
    beforeEach(async () => {
      deployer = (await getNamedAccounts()).deployer;

      await deployments.fixture(["all"]);
      
      SoulBound = await ethers.getContract("SoulBoundToken");
      VotingContract = await ethers.getContract('voting');
      accounts = await ethers.getSigners();
    });

    describe("Create Proposal function", () => {
        beforeEach(async () => {
            await SoulBound.safeMint(accounts[1].address,"first");
            await SoulBound.safeMint(accounts[2].address,"second");
            await SoulBound.safeMint(accounts[3].address,"third");
        });
        it("Should fail if an account without Soulbound tries to create proposal", async () => {
            await expect(VotingContract.createProposal("Abhishek is GAY",10000)).to.be.revertedWith("voting__OnlyPeopleWithSoulBoundTokenCanParticipate")
        });
        it("should pass if the account creating proposal has soulbound ", async () => {
            await expect(VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",10000));
        });
        it("should emit event ", async () => {
            await expect(VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",10000)).emit(VotingContract,"ProposalCreated")
        });
        it("Checks the values that is being emmitted", async () => {
            const trx = await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",10000);
            const trx_recipt = await trx.wait(1);

            const decription = await trx_recipt.events[0].args[0].hash;
            const count = await trx_recipt.events[0].args[1];

            // assert.equal(decription.toString(),ethers.utils.FormatTypes("Abhishek is GAY"));
            assert.equal(count.toString(),"1");
        }); 
        it("checks if the state values are set", async () => {
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",10000);

            const description = await VotingContract.getProposalDescription(0)
            const timestamp = await VotingContract.getProposaldeadline(0);

            const timestamp1 = await time.latest();

            assert.equal(description.toString(), "Abhishek is GAY");
            assert.equal(timestamp,timestamp1+10000);
        });
        it("checks to see if the proposal counter is increased", async () => {
            const x = await VotingContract.getProposalCount();
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",10000);
            const y = await VotingContract.getProposalCount();
            assert(x!=y);
        });
        it("checks if the deadline is 0", async () => {
            const x = await VotingContract.getProposalCount();
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            const y = await VotingContract.getProposalCount();
            assert(x!=y);
        });
        it("should revert if the description is not given", async () => { 
            await expect(VotingContract.connect(accounts[1]).createProposal("",100)).to.be.revertedWith("voting__DescriptionCantBeEmpty")
        });
    });

    describe("Caste Vote Function", async () => {
        beforeEach(async () => {
            await SoulBound.safeMint(accounts[1].address,"first");
            await SoulBound.safeMint(accounts[2].address,"second");
            await SoulBound.safeMint(accounts[3].address,"third");
        });
        it("Should revert if the voter is not a token holder", async () => {
            await expect(VotingContract.connect(accounts[6]).createProposal("",100)).to.be.revertedWith("voting__OnlyPeopleWithSoulBoundTokenCanParticipate")
        });
        it("should revert if the time to caste vote has expired", async () => {
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await time.increase(101);
            await expect(VotingContract.connect(accounts[1]).casteVote(0,1)).to.be.revertedWith("voting__TheTimeToVoteHasExpired");
        });
        it("should revert if the proposal id is inValid", async () => {
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await expect(VotingContract.connect(accounts[1]).casteVote(1,1)).to.be.revertedWith("voting__InvalidProposalId");
        });
        it("should revert if i wish to vote to abstain", async () => {
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await expect(VotingContract.connect(accounts[1]).casteVote(0,0)).to.be.revertedWith("voting__DontVoteIfYouWishToAbstain");
        })
    });

    describe("Checking Other Functions ", async () => {
        beforeEach(async () => {
            await SoulBound.safeMint(accounts[1].address,"first");
            await SoulBound.safeMint(accounts[2].address,"second");
            await SoulBound.safeMint(accounts[3].address,"third");
        });
        it("checking the description getProposalfunctions to see the resulting default values", async () => {
            console.log("---------------DESCRIPTION CHECKS----------------------");
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            const description_exists = await VotingContract.getProposalDescription(0);
            console.log(description_exists.toString());
            const description_noexists = await VotingContract.getProposalDescription(1);
            console.log(` ${description_noexists} no returned values`);
        });
        it("checking the Yes and NO Votes getYesVoteCountfunctions to see the resulting default values", async () => {
            console.log("---------------YES AND NO VOTE COUNT CHECKS----------------------");
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await VotingContract.connect(accounts[1]).casteVote(0,1);
            await VotingContract.connect(accounts[2]).casteVote(0,2);
            const YesVoteCount_exists = await VotingContract.getProposalYesVotes(0);
            await VotingContract.connect(accounts[1]).getProposalYesVotes(0);
            const NoVoteCount_exists = await VotingContract.getProposalNoVotes(0);
            console.log(YesVoteCount_exists.toString() + " Yes Vote Count");
            console.log(NoVoteCount_exists.toString() + " No Vote Count");
            const YesVoteCount_noexists = await VotingContract.getProposalYesVotes(1);
            const NoVoteCount_noexists = await VotingContract.getProposalNoVotes(1);
            console.log(`${YesVoteCount_noexists} else default value for Yes Count`);
            console.log(`${NoVoteCount_noexists} else default value for No count`);
        });
        it("checking the proposal deadline using getProposaldeadline to see the resulting default values", async () => {
            console.log("---------------PROPOSAL DEADLINE CHECKS----------------------");
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            const existingDeadline = await VotingContract.getProposaldeadline(0);
            console.log(`The proposal deadlne if exists ${existingDeadline.toString()}`);
            const defaultDeadline = await VotingContract.getProposaldeadline(1);
            console.log(`${defaultDeadline} is the default value`);
        });
        it("checking is voter values using getProposaldIsVoter function to see the default values", async () => {
            console.log("---------------PROPOSAL VOTER CHECKS----------------------");
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await VotingContract.connect(accounts[1]).casteVote(0,2);
            await VotingContract.connect(accounts[2]).casteVote(0,1);
            const valdiVote = await VotingContract.connect(accounts[1]).getProposaldIsVoter(0);
            console.log(valdiVote.toString() + " Is the catual value");
            const invalidVote = await VotingContract.getProposaldIsVoter(0);
            console.log(`${invalidVote} the default value`);
        });
        it("checks the votes values of a voter using getProposalVoterVote Function to what the voter as voted ", async () => {
            console.log("---------------PROPOSAL VOTER VALUE CHECKS----------------------");
            await VotingContract.connect(accounts[1]).createProposal("Abhishek is GAY",100);
            await VotingContract.connect(accounts[1]).casteVote(0,2);
            await VotingContract.connect(accounts[2]).casteVote(0,1);

            const YESVoter = await VotingContract.connect(accounts[2]).getProposalVoterVote(0);
            console.log(`${YESVoter.toString()} is the value of yes vote`);
            const NoVoter = await VotingContract.connect(accounts[1]).getProposalVoterVote(0);
            console.log(`${NoVoter} is the value of No voter`);
            const NullVoter = await VotingContract.getProposalVoterVote(0);
            console.log(`${NullVoter} is the value of the null value`);
        }) 
    })
});