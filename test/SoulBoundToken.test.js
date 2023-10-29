const { assert, expect } = require("chai");
const { deployments, getNamedAccounts, ethers, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("SoulBound Token Test", () => {
    let Contract;
    let deployer;
    let accounts;
    beforeEach(async () => {
      deployer = (await getNamedAccounts()).deployer;

      await deployments.fixture(["all"]);
      
      Contract = await ethers.getContract('SoulBoundToken');
      accounts = await ethers.getSigners();
    });

    describe("SafeMint Function", () => {
        it("Checks if only the owner can mint the token", async () => {
            await expect(Contract.connect(accounts[1]).safeMint(accounts[1].address, "Hello")).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("only owner can mint", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
        });
        it("should increase the token balance when an Token is minted", async () => {
            const prebalance = await Contract.getTokenCount();
            assert.equal(prebalance.toString(),"0")
            await Contract.safeMint(accounts[1].address, "Hello");  
            const postbalance = await Contract.getTokenCount();
            assert.equal(postbalance.toString(), "1");
        });
        it("updates the balanceOf the user address", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            const balanceOf = await Contract.balanceOf(accounts[1].address);
            assert.equal(balanceOf.toString(),"1");
            const ownerOf = await Contract.ownerOf("0");
            assert.equal(ownerOf.toString(),accounts[1].address )
        });
        it("should revert if the minting address is address 0", async () => {
            await expect(Contract.safeMint(ethers.constants.AddressZero, "Hello")).to.be.revertedWith("ERC721: address zero is not a valid owner");
        });
        it("Should update the token URIs Mapping", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            const tokenURI = await Contract.tokenURI("0");
            assert.equal(tokenURI.toString(),"Hello");
        });
        it("Emits an Event", async () => {
            await expect(Contract.safeMint(accounts[1].address, "Hello")).to.emit(Contract,"Transfer").withArgs(ethers.constants.AddressZero,accounts[1].address,0);
            // The below event test will result in the updated tokencounter to 1 since i am minting twice
            await expect(Contract.safeMint(accounts[2].address, "Hello123")).to.emit(Contract,"Attest").withArgs(accounts[2].address,1);
        });
        it("Should revert if i have already minted tokens ", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.safeMint(accounts[1].address, "Hello")).to.be.revertedWith("SoulBoundToken__CantMintToAnExistingOwner")
        })
    });

    describe("Burn function", () => {
        it("The token burn should fail, if the address buring the token inst the owner of the token", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.burn("0")).to.be.revertedWith("Only owner of the token can burn it");
        });
        it("It should burn only if the owner of the token call it", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            Contract.connect(accounts[1]).burn("0");
        });
        it("Should fail if the token being burn is invalid token ID", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.burn("1")).to.be.revertedWith("ERC721: invalid token ID");
        });
        it("Even after the token has been burned the token count should remain same", async () => {
            const y = await Contract.getTokenCount();
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.connect(accounts[1]).burn("0");
            const x = await Contract.getTokenCount();
            assert(y < x)
        });
        it("Should delete the mapping", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.connect(accounts[1]).burn("0");
            await expect(Contract.tokenURI(0)).to.be.revertedWith("ERC721: invalid token ID");
        });
        it("Should emit Events", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.connect(accounts[1]).burn(0)).to.emit(Contract,"Transfer").withArgs(accounts[1].address,ethers.constants.AddressZero,0);
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.connect(accounts[1]).burn(1)).to.emit(Contract,"Revoke").withArgs(ethers.constants.AddressZero,1)
        });
    });

    describe("Checks the revoke function", () => {
        it("Should fails if someone apart from the deployer call the function", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await expect(Contract.connect(accounts[1]).revoke(0)).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("Only the owner can call the function", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.revoke(0)
            await expect(Contract.tokenURI(0)).to.be.revertedWith("ERC721: invalid token ID");
        });
        it("Shpould succesfull revoke ", async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.revoke(0)
            const x = await Contract.balanceOf(accounts[1].address);
            assert.equal(x.toString(),"0");
        })
    })

    describe("Checks the Approval, transferFrom, Burn functions", () => {
        beforeEach(async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.safeMint(accounts[2].address, "Hello");
            await Contract.connect(accounts[1]).approve(accounts[0].address,"0");
            await Contract.connect(accounts[2]).approve(accounts[0].address,"1");
        });
        it("fails if the approver tries to burn the token", async () => {
            await expect(Contract.burn("0")).to.be.revertedWith("Only owner of the token can burn it");
        });
        it("Should if the approved tries to transfer token to address(0)", async () => {
            await expect(Contract.transferFrom(accounts[1].address,ethers.constants.AddressZero,"0")).to.be.revertedWith("ERC721: transfer to the zero address");
        });
        it("should revert is the token is being transfered to someother account", async () => {
            await expect(Contract.transferFrom(accounts[1].address,accounts[0].address,"0")).to.be.revertedWith("Not allowed to transfer token");
        });
        it("should revert is the token is being transfered to someother account using safeTransferFrom", async () => {
            await expect(Contract["safeTransferFrom(address,address,uint256)"](accounts[1].address, accounts[0].address, "0"))
            .to.be.revertedWith("Not allowed to transfer token");
            await expect(Contract.connect(accounts[1])["safeTransferFrom(address,address,uint256,bytes)"](accounts[1].address, accounts[0].address, "0", "0x00"))
            .to.be.revertedWith("Not allowed to transfer token");
        });
        it("should revert is the token is being transfered to someother account", async () => {
            await expect(Contract.connect(accounts[1]).transferFrom(accounts[1].address,accounts[0].address,"0")).to.be.revertedWith("Not allowed to transfer token");
        });
    });

    describe("checks the other functions ", () => {
        beforeEach(async () => {
            await Contract.safeMint(accounts[1].address, "Hello");
            await Contract.safeMint(accounts[2].address, "Hello");
            await Contract.connect(accounts[1]).approve(accounts[0].address,"0");
            await Contract.connect(accounts[2]).approve(accounts[0].address,"1");
        });
        it("checks the approved token mapping function", async () => {
            const x = await Contract._tokenIdCounter();
            assert.equal(x.toString(),"2");
        });
        it("checks the get approved function", async () => {
            const x = await Contract.getApproved("0");
            assert.equal(x,accounts[0].address)
        })
    })
});
