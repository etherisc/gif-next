// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";

interface INftOwnable is
    IERC165
{
    error ErrorInitialOwnerZero();
    error ErrorNotOwner(address account);

    error ErrorAlreadyLinked(address registry, NftId nftId);
    error ErrorRegistryAlreadyInitialized(address registry);
    error ErrorRegistryNotInitialized();
    error ErrorRegistryAddressZero();
    error ErrorNotRegistry(address registryAddress);
    error ErrorContractNotRegistered(address contractAddress);

    function linkToRegisteredNftId() external;

    function getRegistry() external view returns (IRegistry);
    function getNftId() external view returns (NftId);
    function getOwner() external view returns (address);
}