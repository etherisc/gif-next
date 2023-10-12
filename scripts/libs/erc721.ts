import { ethers } from "ethers";
import * as iERC721Abi from "../../artifacts/@openzeppelin/contracts/token/ERC721/ERC721.sol/ERC721.json";


export const IERC721ABI = new ethers.Interface(iERC721Abi.abi);


import * as iRegistryAbi from "../../artifacts/contracts/registry/Registry.sol/Registry.json";

export const IRegistryABI = new ethers.Interface(iRegistryAbi.abi);
