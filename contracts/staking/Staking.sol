// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ObjectType, REGISTRY, STAKING} from "../type/ObjectType.sol";
import {NftId, zeroNftId} from "../type/NftId.sol";
import {Version, VersionLib, VersionPartLib} from "../type/Version.sol";

import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";
import {Registerable} from "../shared/Registerable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

contract Staking is 
    Registerable,
    Versionable,
    AccessManagedUpgradeable,
    IStaking
{

    uint8 private constant GIF_MAJOR_VERSION = 3;

    // from Versionable
    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(GIF_MAJOR_VERSION,0,0);
    }

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer
    {
        (
            address registryAddress,
            address initialAuthority,
            address initialOwner
        ) = abi.decode(data, (address, address, address));

        initializeRegisterable(
            registryAddress, 
            IRegistry(registryAddress).getNftId(), 
            STAKING(), 
            false, // is interceptor
            initialOwner, 
            ""); // data

        __AccessManaged_init(initialAuthority);

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IStaking).interfaceId);
    }
}
