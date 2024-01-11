// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../types/NftId.sol";

interface IBaseComponent is IRegisterable {

    function lock() external;

    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function getWallet() external view returns (address walletAddress);

    function getInstance() external view returns (IInstance instance);

    function getProductNftId() external view returns (NftId productNftId);

}