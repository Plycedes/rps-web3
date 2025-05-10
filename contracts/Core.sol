// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error NotTokenOwner(uint256 tokenId, address caller);
error NotTokenSeller(uint256 tokenId, address caller);
error TokenNotListed(uint256 tokenId);

contract Core is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIds;

    struct Listing {
        uint256 price;
        address seller;
    }

    // tokenId => Listing
    mapping(uint256 => Listing) public listings;    

    event NFTMinted(uint256 indexed tokenId, address indexed creator, string tokenURI);
    event NFTListed(uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTSold(uint256 indexed tokenId, uint256 price, address indexed buyer);    
    event NFTUnlisted(uint256 indexed tokenId, address indexed seller);

    constructor() ERC721("MyNFTCollection", "MNFT") Ownable(msg.sender) {}
    
    function mintNFT(string memory tokenURI) external returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        emit NFTMinted(newItemId, msg.sender, tokenURI);
        return newItemId;
    }

    function unlistNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];

        if (listing.price == 0) {
            revert TokenNotListed(tokenId);
        }

        if (listing.seller != msg.sender) {
            revert NotTokenSeller(tokenId, msg.sender);
        }

        delete listings[tokenId];

        emit NFTUnlisted(tokenId, msg.sender);
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
        
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Payment to seller failed");

        
        _transfer(listing.seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.value, msg.sender);
    }
        
    function transferNFTToWinner(uint256 tokenId, address winner) external  {        
        if (ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(tokenId, msg.sender);
        }
        _transfer(msg.sender, winner, tokenId);
    }    
}
