const { assert, expect } = require("chai");
const { deployments, getNamedAccounts, ethers, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

developmentChains.includes(network.name)
  ? describe.skip
  : describe("FundVoting Test",() => {
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
            await expect(FundVoting.createProposal("Hello", 100, 100)).to.be.revertedWith("FundVoting__OnlyMemberAllowed()");
        })
    })
  })