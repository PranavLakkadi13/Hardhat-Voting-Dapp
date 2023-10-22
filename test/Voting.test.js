const { assert, expect } = require("chai");
const { deployments, getNamedAccounts, ethers, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const {time} = require("@nomicfoundation/hardhat-network-helpers");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Voting", () => {
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
        
    })

});