import { ethers } from "ethers";
import * as iERC721Abi from "../../artifacts/@openzeppelin5/contracts/token/ERC721/IERC721.sol/IERC721.json";

export const IERC721ABI = new ethers.Interface(iERC721Abi.abi);
