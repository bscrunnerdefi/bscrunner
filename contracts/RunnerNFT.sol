// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../oz/utils/structs/EnumerableSet.sol";
import "../oz/access/Ownable.sol";
import "../oz/token/ERC721/extensions/ERC721Enumerable.sol";

contract RunnerNFT is ERC721Enumerable, Ownable  {
    
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for uint256;
    
    struct Type {
        uint id;
        uint bonus;
        uint rarity;
    }
    
    constructor() ERC721("Runner NFT","RunnerNFT") {} 
    
    // Token.Type data
    EnumerableSet.UintSet typeIds;
    
    mapping (uint=>Type) typesById;
    mapping (uint=>EnumerableSet.UintSet) private typeIdsByRarity;
    mapping (uint=>uint) private mintIndexByTokenId;
    // Token data
    uint nextTokenId = 0;
    mapping (uint=>uint) private typeIdByTokenId;
    
    function createToken(address holder, uint typeId) public onlyOwner returns (uint tokenId) {
        tokenId = ++nextTokenId;
        typeIdByTokenId[tokenId] = typeId;
        _mint(holder, tokenId);
    }
    
    function createRandomTokenWithRarity(address holder, uint rarity, uint seed) public onlyOwner returns (uint) {
        EnumerableSet.UintSet storage filter = typeIdsByRarity[rarity];
        require(filter.length() > 0, "there are no types with that rarity");
        uint typeId = filter.at(seed % filter.length());
        return createToken(holder, typeId);
    }
    
    function addType(uint id, uint bonus, uint rarity) public onlyOwner {
        require(!typeIds.contains(id), "id already exists");
        typeIds.add(id);
        typesById[id] = Type(id, bonus, rarity);
        typeIdsByRarity[rarity].add(id);
    }
    
    function removeType(uint id) public onlyOwner {
        require(typeIds.contains(id), "id does not exist");
        typeIds.remove(id);
        typeIdsByRarity[typesById[id].rarity].remove(id);
    }
    
    function getTypeById(uint id) public view returns (Type memory) { return typesById[id]; }
    
    function getTypeByTokenId(uint id) public view returns (Type memory) { return typesById[typeIdByTokenId[id]]; }
    
    
    /*
        These 3 functions help to iterate through all types
    */
    
    function getTypeCount() public view returns (uint) {
        return typeIds.length();
    }
    
    function getTypeIdAtIndex(uint index) public view returns (uint) {
        return typeIds.at(index);
    }
    
    function getTypeAtIndex(uint index) public view returns (Type memory tokenType) {
        tokenType = typesById[typeIds.at(index)];
    }
    
    
    /*
        The following functions override ERC721's in order to provide specialized
        name and symbol according to our token type.
    */
    
    /*
        The default uri is to combine _baseURI with tokenId, e.g., "https://token-data.super-awesome-project.tld/{tokenId}"
        If our server cannot read the block chain in order to look up the Token.Type data, we will need to override another
        function to also supply the Token.Type information.
    */
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://nft.bscrunner.com/";
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        string memory baseURI = ERC721.tokenURI(tokenId);
        Type memory tokenType = getTypeByTokenId(tokenId);
        return string(abi.encodePacked(
            baseURI, "/",
            tokenId.toString(), "/",
            tokenType.bonus.toString(), "/",
            tokenType.rarity.toString()));
    }
    
}