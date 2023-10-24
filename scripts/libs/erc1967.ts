import { ethers } from "ethers";
import * as iERC1967Abi from "../../artifacts/@openzeppelin5/contracts/interfaces/IERC1967.sol/IERC1967.json";

export const IERC1967ABI = new ethers.Interface(iERC1967Abi.abi);
