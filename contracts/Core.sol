// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error NotTokenOwner(uint256 tokenId, address caller);

contract Core is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIds;

    struct Listing {
        uint256 price;
        address seller;
    }

    // tokenId => Listing
    mapping(uint256 => Listing) public listings;

    // Seller => Proceeds
    mapping(address => uint256) public proceeds;

    event NFTMinted(uint256 indexed tokenId, address indexed creator, string tokenURI);
    event NFTListed(uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTSold(uint256 indexed tokenId, uint256 price, address indexed buyer);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);

    constructor() ERC721("MyNFTCollection", "MNFT") Ownable(msg.sender) {}
    
    function mintNFT(string memory tokenURI) external returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        emit NFTMinted(newItemId, msg.sender, tokenURI);
        return newItemId;
    }
    
    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(price > 0, "Price must be greater than 0");
        approve(address(this), tokenId);

        listings[tokenId] = Listing(price, msg.sender);
        emit NFTListed(tokenId, price, msg.sender);
    }
    
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.price > 0, "NFT not for sale");
        require(msg.value >= listing.price, "Not enough ETH sent");
        
        delete listings[tokenId];
        
        proceeds[listing.seller] += msg.value;
        
        _transfer(listing.seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.value, msg.sender);
    }
    
    function withdrawProceeds() external nonReentrant {
        uint256 amount = proceeds[msg.sender];
        require(amount > 0, "No proceeds to withdraw");

        proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit ProceedsWithdrawn(msg.sender, amount);
    }
        
    function transferNFTToWinner(uint256 tokenId, address winner) external  {        
        if (ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(tokenId, msg.sender);
        }
        _transfer(msg.sender, winner, tokenId);
    } 
    
    function getListedNFTs() external view returns (uint256[] memory) {
        uint256 total = _tokenIds;
        uint256 count;
        
        for (uint256 i = 1; i <= total; i++) {
            if (listings[i].price > 0) {
                count++;
            }
        }
        
        uint256[] memory listed = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (listings[i].price > 0) {
                listed[idx++] = i;
            }
        }

        return listed;
    }
    
    function getUserNFTs(address user) external view returns (uint256[] memory) {
        uint256 total = _tokenIds;
        uint256 count;

        for (uint256 i = 1; i <= total; i++) {
            try this.ownerOf(i) returns (address nftOwner) {
                if (nftOwner == user) count++;
            } catch {}

        }

        uint256[] memory owned = new uint256[](count);
        uint256 idx = 0;

        for (uint256 i = 1; i <= total; i++) {
            try this.ownerOf(i) returns (address nftOwner) {
                if (nftOwner == user) owned[idx++] = i;
            } catch {}

        }

        return owned;
    }

    
    function getSingleNFT(uint256 tokenId) external view returns 
        (
            address owner,
            address seller,
            uint256 price,
            string memory uri
        )
    {
        try this.ownerOf(tokenId) returns (address nftOwner) {
            owner = nftOwner;
        } catch {
            revert("NFT does not exist");
        }

        seller = listings[tokenId].seller;
        price = listings[tokenId].price;
        uri = tokenURI(tokenId);
    }       
    receive() external payable {}
}
