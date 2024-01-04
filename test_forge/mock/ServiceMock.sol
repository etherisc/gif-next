// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId} from "../../contracts/types/NftId.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {ObjectType, toObjectType, SERVICE} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";
//import {IVersionable} from "../../contracts/shared/IVersionable.sol";
//import {Versionable} from "../../contracts/shared/Versionable.sol";

//import {IService} from "../../contracts/instance/base/IService.sol";

contract ServiceMock is ServiceBase {

    string public constant NAME = "ServiceMock";

    constructor(address registry, NftId registryNftId, address initialOwner)
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }
}

contract ServiceMockWithRandomInvalidType is ServiceBase {

    string public constant NAME = "ServiceMockWithRandomInvalidType";

    ObjectType public _invalidType;

    constructor(address registry, NftId registryNftId, address initialOwner)
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);

        FoundryRandom rng = new FoundryRandom();

        ObjectType invalidType = toObjectType(rng.randomNumber(type(uint96).max));
        if(invalidType == SERVICE()) {
            invalidType = toObjectType(invalidType.toInt() + 1);
        }

        _invalidType = invalidType;
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }

    function getInitialInfo() 
        public 
        view 
        virtual override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectType = _invalidType;

        return (info, data);
    }
}

contract ServiceMockWithRandomInvalidAddress is ServiceBase {

    string public constant NAME = "ServiceMockWithRandomInvalidAddress";

    address public _invalidAddress;

    constructor(address registry, NftId registryNftId, address initialOwner)
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);

        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _invalidAddress = invalidAddress;
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }

    function getInitialInfo() 
        public 
        view 
        virtual override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory) 
    {
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = super.getInitialInfo();

        info.objectAddress = _invalidAddress;

        return (info, data);
    }
}

contract ServiceMockWithTooOldVersion is ServiceBase {

    string public constant NAME = "ServiceMockWithTooOldVersion";

    constructor(address registry, NftId registryNftId, address initialOwner)
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }

    function getVersion() public pure override returns(Version)
    {
        return VersionLib.toVersion(2,0,0);
    }
}

contract ServiceMockWithTooNewVersion is ServiceBase {

    string public constant NAME = "ServiceMockWithTooNewVersion";

    constructor(address registry, NftId registryNftId, address initialOwner)
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);
    }

    function getName() public pure override returns(string memory name) {
        return NAME;
    }

    function getVersion() public pure override returns(Version)
    {
        return VersionLib.toVersion(4,0,0);
    }
}

