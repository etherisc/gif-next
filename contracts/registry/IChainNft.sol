// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IChainNft is 
    IERC721Enumerable 
{

    function mint(address to, string memory uri) external returns(uint256 tokenId);
    function burn(uint256 tokenId) external;
    function setURI(uint256 tokenId, string memory uri) external;

    function exists(uint256 tokenId) external view returns(bool);
    function totalMinted() external view returns(uint256);

    function getRegistryAddress() external view returns(address registry);
}
