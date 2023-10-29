const { assert, expect } = require("chai");
const { deployments, getNamedAccounts, ethers, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const {time} = require("@nomicfoundation/hardhat-network-helpers");

describe("FundVoting Test",() => {
    let TokenContract;
    let FundVoting;
    let deployer;
    let accounts;
    beforeEach(async () => {
      deployer = (await getNamedAccounts()).deployer;

      await deployments.fixture(["all"]);
      
      TokenContract = await ethers.getContract('SoulBoundToken');
      FundVoting = await ethers.getContract('FundVoting');
      accounts = await ethers.getSigners();

      for(let i = 0; i < 4; i++) {
        await TokenContract.safeMint(accounts[i].address,`${i}`);
      }

    });

    describe("Create Proposal Function", () => {
        it("Should fail if a non-Soul Token owner calls it", async () => {
            await expect(FundVoting.connect(accounts[6]).createProposal("Hello", 100, 100)).to.be.revertedWith("FundVoting__OnlyMemberAllowed");
        });
        it("Should succeed if soul token owner calls it", async () => {
            await FundVoting.createProposal("Hello",100,100);
        });
        it("should revert if the goal amount is 0", async () => {
            await expect(FundVoting.createProposal("Hello", 100, 0)).to.be.revertedWith("FundVoting__ValueShouldBeGreaterThanZero");
        });
        it("should allow multiple proposals at a time", async () => {
            await FundVoting.createProposal("Hello",100,100);
            await FundVoting.createProposal("Hello",100,100);
            await FundVoting.createProposal("Hello",100,100);
            const proposalCount = await FundVoting.getProposalCount()
            assert.equal(proposalCount.toString(),3)
        });
        it("Should emit an event when a proposal is Created", async () => {
            await expect(FundVoting.createProposal("hello",100,100)).to.emit(FundVoting,"ProposalCreated");
        });
        it("Checking the emitted events", async () => {
            const trx = await FundVoting.createProposal("hello",100,100);
            const trxReceipt = await trx.wait();
            
            const description = await trxReceipt.events[0].args[0];
            const deadline = await trxReceipt.events[0].args[1];
            const goal = await trxReceipt.events[0].args[2].toString();

            assert(deadline.toString() == "100");
            assert(goal == ethers.utils.parseUnits("100","wei"));
        });
        it("Make state Changes and store the info ", async () => {
            const time1 = await time.latest();
            await FundVoting.createProposal("Hello",100,100);

            const remainingBalance = await FundVoting.getRemainingBalance(0);
            const description = await FundVoting.getProposalDescription(0);
            const owner = await FundVoting.getProposalOwner(0);
            const deadline = await FundVoting.getProposalDeadline(0);
            const goal = await FundVoting.getProposalGoal(0);
            const Contributor_contribution = await FundVoting.getProposalContributor_Contribution(0,accounts[0].address);
            const contrutorsCOunt = await FundVoting.getProposalContributionCounter(0);
            const RequestCOunt = await FundVoting.getProposalRequestCount(0);

            await expect(FundVoting.getProposalActiveRequest(1)).to.be.revertedWith("FundVoting__InvalidProposal")
            const ActiveRequest = await FundVoting.getProposalActiveRequest(0);

            assert.equal(remainingBalance.toString(),0);
            assert.equal(description.toString(),"Hello");
            assert.equal(owner,accounts[0].address);
            assert.equal(deadline.toString(),time1+101);
            assert.equal(goal.toString(),"100");
            assert.equal(Contributor_contribution.toString(),"0");
            assert.equal(contrutorsCOunt.toString(),0);
            assert(RequestCOunt.toString() == 0);
            assert.equal(ActiveRequest.toString(), "false");

        });
    });

    describe("Contribute Funtion", () => {
        it("Should revert if the in correct proposal Id is given", async () => {
            await expect(FundVoting.connect(accounts[6]).Contribute(0)).to.be.revertedWith("FundVoting__InvalidProposal");
        });
        it("Should revert if a non soul token owner calls it", async () => {
            await FundVoting.createProposal("Hello",100,100);
            await expect(FundVoting.connect(accounts[6]).Contribute(0)).to.be.revertedWith("FundVoting__OnlyMemberAllowed");
        });
        it("Should fail if the time to contribute has expired ", async () => {
            await FundVoting.createProposal("Hello",100,100);
            await FundVoting.connect(accounts[1]).Contribute(0, {value : 1000} )
            await time.increase(101)
            await expect(FundVoting.connect(accounts[1]).Contribute(0)).to.be.revertedWith("FundVoting__TimeToContributeExpired");
        });
        it("Should Revert if the value being sent is 0", async () => {
            await FundVoting.createProposal("Hello",100,100);
            await expect(FundVoting.connect(accounts[1]).Contribute(0)).to.be.revertedWith("FundVoting__ValueShouldBeGreaterThanZero");
        });
        it("SHould have a successful contribution", async () => {
            await FundVoting.createProposal("Hello",100,100);
            for (let index = 0; index < 4; index++) {
                await FundVoting.connect(accounts[index]).Contribute(0,{value: 1000});
            }
        });
        it("Emits an Event when successfully contributed", async () => {
            await FundVoting.createProposal("Hello",100,100);
            await expect(FundVoting.connect(accounts[1]).Contribute(0,{value: 1000})).to.emit(FundVoting,"Contributed")
        });
        it("checking if it emits the right values", async () => {
            await FundVoting.createProposal("Hello",100,100);
            const trx = await FundVoting.connect(accounts[1]).Contribute(0,{value: 1000});
            const trxreceipt  = await trx.wait(1);

            const contributor = await trxreceipt.events[0].args[0];
            const amount = await trxreceipt.events[0].args[1].toString();

            assert.equal(contributor,accounts[1].address);
            assert.equal(amount.toString(),ethers.utils.parseUnits("1000","wei"));
        });
        it("Checks the state changes", async () => {
            await FundVoting.createProposal("Hello",100,100);
            for (let index = 0; index < 4; index++) {
                await FundVoting.connect(accounts[index]).Contribute(0,{value: 1000});
            }
            await FundVoting.connect(accounts[1]).Contribute(0,{value: 1000});
            await FundVoting.connect(accounts[1]).Contribute(0,{value: 1000});

            const contributorCount = await FundVoting.getProposalContributionCounter(0);
            const remainingBalance = await FundVoting.getRemainingBalance(0);
            const ContributorsCOntribution = await FundVoting.getProposalContributor_Contribution(0,accounts[1].address);

            assert.equal(contributorCount.toString(), "4");
            assert.equal(remainingBalance.toString(), ethers.utils.parseUnits("6000","wei"));
            assert.equal(ContributorsCOntribution.toString(),"3000");
            assert.equal(ContributorsCOntribution.toString(), ethers.utils.parseUnits("3000","wei"));
        });
    });
  })