// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin5/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IOwnable} from "./IOwnable.sol";

interface IRegisterable is IERC165, IOwnable {
    function getRegistry() external view returns (IRegistry registry);

    function getNftId() external view returns (NftId nftId);

    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory, bytes memory data);

}