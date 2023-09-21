// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IOwnable} from "./IOwnable.sol";
import {IRegistryLinked} from "../registry/IRegistryLinked.sol";

interface IRegisterable is IOwnable, IRegistryLinked {
    function register() external returns (NftId nftId);

    function getType() external pure returns (ObjectType objectType);

    function getNftId() external view returns (NftId nftId);

    function getParentNftId() external view returns (NftId nftId);

    function getData() external view returns (bytes memory data);
}
