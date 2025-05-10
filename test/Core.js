const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace", function () {
    let nftMarketplace, deployer, user1, user2;

    beforeEach(async function () {
        [deployer, user1, user2] = await ethers.getSigners();
        nftMarketplace = await ethers.deployContract("Core");
    });

    describe("Listing NFTs", function () {
        it("should mint an NFT", async function () {
            await expect(nftMarketplace.connect(user1).mintNFT("ipfs://test-token-uri"))
                .to.emit(nftMarketplace, "NFTMinted")
                .withArgs(1, user1.address, "ipfs://test-token-uri");
        });

        it("should list an NFT for sale", async function () {
            await expect(nftMarketplace.connect(user1).mintNFT("ipfs://uri"))
                .to.emit(nftMarketplace, "NFTMinted")
                .withArgs(1, user1.address, "ipfs://uri");

            await expect(nftMarketplace.connect(user1).listNFT(1, ethers.parseEther("1")))
                .to.emit(nftMarketplace, "NFTListed")
                .withArgs(1, ethers.parseEther("1"), user1.address);

            const listing = await nftMarketplace.listings(1);
            expect(listing.price.toString()).to.equal(ethers.parseEther("1").toString());
            expect(listing.seller).to.equal(user1.address);
        });

        it("should revert if non-owner tries to list", async function () {
            await nftMarketplace.connect(user1).mintNFT("ipfs://uri");

            await expect(
                nftMarketplace.connect(user2).listNFT(1, ethers.parseEther("1"))
            ).to.be.revertedWith("You don't own this NFT");
        });
    });

    describe("Unlisting NFTs", function () {
        let tokenId;

        beforeEach(async function () {
            const mintTx = await nftMarketplace.connect(user1).mintNFT("ipfs://token-uri");
            const receipt = await mintTx.wait();
            tokenId = receipt.logs[0].args.tokenId;

            await nftMarketplace.connect(user1).listNFT(tokenId, ethers.parseEther("1"));
        });

        it("should allow the seller to unlist their NFT", async function () {
            await expect(nftMarketplace.connect(user1).unlistNFT(tokenId))
                .to.emit(nftMarketplace, "NFTUnlisted")
                .withArgs(tokenId, user1.address);

            const listing = await nftMarketplace.listings(tokenId);
            expect(listing.price).to.equal(0);
            expect(listing.seller).to.equal("0x0000000000000000000000000000000000000000");
        });

        it("should revert if someone other than the seller tries to unlist", async function () {
            await expect(nftMarketplace.connect(user2).unlistNFT(tokenId))
                .to.be.revertedWithCustomError(nftMarketplace, "NotTokenSeller")
                .withArgs(tokenId, user2.address);
        });

        it("should revert if NFT is not listed", async function () {
            await nftMarketplace.connect(user1).unlistNFT(tokenId);

            await expect(nftMarketplace.connect(user1).unlistNFT(tokenId))
                .to.be.revertedWithCustomError(nftMarketplace, "TokenNotListed")
                .withArgs(tokenId);
        });
    });

    describe("Buys NFTs", function () {
        it("should allow a user to buy a listed NFT and pay seller directly", async function () {
            await nftMarketplace.connect(user1).mintNFT("ipfs://uri");
            await nftMarketplace.connect(user1).listNFT(1, ethers.parseEther("1"));

            const sellerInitialBalance = await ethers.provider.getBalance(user1.address);

            const tx = await nftMarketplace
                .connect(user2)
                .buyNFT(1, { value: ethers.parseEther("1") });
            const receipt = await tx.wait();

            await expect(tx)
                .to.emit(nftMarketplace, "NFTSold")
                .withArgs(1, ethers.parseEther("1"), user2.address);

            expect(await nftMarketplace.ownerOf(1)).to.equal(user2.address);

            const sellerFinalBalance = await ethers.provider.getBalance(user1.address);

            expect(sellerFinalBalance - sellerInitialBalance).to.be.closeTo(
                ethers.parseEther("1"),
                ethers.parseEther("0.001")
            );
        });

        it("should revert on buy if not enough ETH sent", async function () {
            await nftMarketplace.connect(user1).mintNFT("ipfs://uri");
            await nftMarketplace.connect(user1).listNFT(1, ethers.parseEther("1"));

            await expect(
                nftMarketplace.connect(user2).buyNFT(1, { value: ethers.parseEther("0.5") })
            ).to.be.revertedWith("Not enough ETH sent");
        });
    });

    describe("Admin NFT Transfer to Winner", function () {
        it("should allow admin to transfer NFT to a winner", async () => {
            const tokenURI = "ipfs://tournament-nft";

            const mintTx = await nftMarketplace.connect(user1).mintNFT(tokenURI);
            const mintReceipt = await mintTx.wait();
            const tokenId = mintReceipt.logs[0].args.tokenId;

            await expect(nftMarketplace.connect(user1).transferNFTToWinner(tokenId, user2.address))
                .to.emit(nftMarketplace, "Transfer")
                .withArgs(user1.address, user2.address, tokenId);

            const newOwner = await nftMarketplace.ownerOf(tokenId);
            expect(newOwner).to.equal(user2.address);
        });

        it("should revert if non-admin tries to transfer", async () => {
            const tokenURI = "ipfs://tournament-nft-2";
            const mintTx = await nftMarketplace.connect(user1).mintNFT(tokenURI);
            const mintReceipt = await mintTx.wait();
            const tokenId = mintReceipt.logs[0].args.tokenId;

            await expect(
                nftMarketplace.connect(user2).transferNFTToWinner(tokenId, user2.address)
            ).to.be.revertedWithCustomError(nftMarketplace, "NotTokenOwner");
        });
    });
});
