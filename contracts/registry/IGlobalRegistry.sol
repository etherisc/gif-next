// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";

import {IRegistry} from "./IRegistry.sol";

interface IGlobalRegistry is IRegistry {

    function registerChainRegistry(uint chainId, address deployer) external returns (NftId chainRegistryNftId, address chainRegistryAddress);

    function getChainRegistry(uint chainId) external returns (address);
}