// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin5/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

interface IRegisterable is IERC165 {
    function getRegistry() external view returns (IRegistry registry);

    function getNftId() external view returns (NftId nftId);

    function getOwner() external view returns (address owner);

    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory, bytes memory data);

}