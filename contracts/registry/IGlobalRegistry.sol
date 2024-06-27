// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../type/NftId.sol";

import {IRegistry} from "./IRegistry.sol";

interface IGlobalRegistry is IRegistry {
    // function registerChainRegistry(uint chainId, address deployer, bytes32 initCodeHash, bytes32 salt);
    function registerChainRegistry(uint chainId, address chainRegistryAddress) external returns (NftId chainRegistryNftId);

    function getChainRegistryAddress(uint chainId) external returns (address); 

    function getChainId(uint idx) external view returns (uint);

    function chainIds() external view returns (uint);
}