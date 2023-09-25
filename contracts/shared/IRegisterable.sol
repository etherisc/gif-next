// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IOwnable} from "./IOwnable.sol";

interface IRegisterable is IERC165, IOwnable {

    function register() external returns (NftId nftId);

    function getInfo() external view returns (IRegistry.ObjectInfo memory info);

    function getRegistry() external view returns (IRegistry registry);
    
    function getType() external pure returns (ObjectType objectType);

    function getNftId() external view returns (NftId nftId);

    function getParentNftId() external view returns (NftId nftId);

    function getData() external view returns (bytes memory data);
}
