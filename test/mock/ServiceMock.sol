// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {NftId} from "../../contracts/type/NftId.sol";
import {Version, VersionPart, VersionLib, VersionPartLib} from "../../contracts/type/Version.sol";
import {ObjectType, ObjectTypeLib, REGISTRY, SERVICE, PRODUCT, POOL, ORACLE, DISTRIBUTION} from "../../contracts/type/ObjectType.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRelease} from "../../contracts/registry/IRelease.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {RegisterableMockWithAuthority} from "./RegisterableMock.sol";
import {RoleId, RoleIdLib} from "../../contracts/type/RoleId.sol";

contract ServiceMock is RegisterableMockWithAuthority, IService {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        RegisterableMockWithAuthority(
            initialAuthority,
            nftId,
            registryNftId,
            SERVICE(),
            isInterceptor,
            initialOwner,
            "")
    {
        _info.data = abi.encode(getDomain(), getVersion().toMajorPart());
        initialize(initialAuthority);
    }

    function initialize(address initialAuthority) internal initializer() {
        _registerInterface(type(IService).interfaceId);
    }

    // from IRegisterable / IService
    function getRelease() public pure virtual override (IRelease, RegisterableMockWithAuthority) returns(VersionPart) {
        return VersionPartLib.toVersionPart(3);
    }

    // from IService
    function getDomain() public pure virtual returns(ObjectType) {
        return PRODUCT();
    }

    function getRoleId() external virtual override pure returns(RoleId serviceRoleId) {
        return RoleIdLib.toServiceRoleId(getDomain(), getRelease());
    }

    // from IVersionable
    function getVersion()
        public 
        pure 
        virtual override// (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(uint8(getRelease().toInt()),0,0);
    }
    
    // from IVersionable, DON NOT USE
    function initializeVersionable(address activatedBy, bytes memory activationData) external { revert("not implemented"); }
    function upgradeVersionable(bytes memory upgradeData) external { revert("not implemented"); }
}

contract SelfOwnedServiceMock is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialAuthority)
        ServiceMock(
            nftId, 
            registryNftId, 
            isInterceptor, 
            address(this),
            initialAuthority)
    {}

    function getDomain() public pure override returns(ObjectType) {
        return DISTRIBUTION();
    }
}

contract ServiceMockWithRandomInvalidType is ServiceMock {

    ObjectType public immutable _invalidType;

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner,
            initialAuthority)
    {
        FoundryRandom rng = new FoundryRandom();

        ObjectType invalidType = ObjectTypeLib.toObjectType(rng.randomNumber(type(uint96).max));
        if(invalidType == SERVICE()) {
            invalidType = ObjectTypeLib.toObjectType(invalidType.toInt() + 1);
        }

        _info.objectType = invalidType;
        _invalidType = invalidType;
    }

    function getDomain() public pure override returns(ObjectType) {
        return ORACLE();
    }

    function getRoleId() external virtual override pure returns(RoleId serviceRoleId) {
        return RoleIdLib.toServiceRoleId(getDomain(), VersionPartLib.toVersionPart(3));
    }
}

contract ServiceMockWithRandomInvalidAddress is ServiceMock {

    address public immutable _invalidAddress;

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner,
            initialAuthority)
    {
        FoundryRandom rng = new FoundryRandom();

        address invalidAddress = address(uint160(rng.randomNumber(type(uint160).max)));
        if(invalidAddress == address(this)) {
            invalidAddress = address(uint160(invalidAddress) + 1);
        }

        _info.objectAddress = invalidAddress;
        _invalidAddress = invalidAddress;
    }

    function getDomain() public pure override returns(ObjectType) {
        return POOL();
    }

    function getRoleId() external virtual override pure returns(RoleId serviceRoleId) {
        return RoleIdLib.toServiceRoleId(getDomain(), VersionPartLib.toVersionPart(3));
    }
}

contract ServiceMockOldVersion is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner,
            initialAuthority)
    {}

    function getRelease() public pure virtual override returns(VersionPart) { return VersionPartLib.toVersionPart(2); }
}

contract ServiceMockNewVersion is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner,
            initialAuthority)
    {}
}

contract ServiceMockWithRegistryDomainV3 is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(nftId, registryNftId, isInterceptor, initialOwner, initialAuthority)
    {}

    function getDomain() public pure virtual override returns(ObjectType) { return REGISTRY(); }
}

contract ServiceMockWithRegistryDomainV4 is ServiceMock 
{
    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(nftId, registryNftId, isInterceptor, initialOwner, initialAuthority)
    {}

    function getRelease() public pure virtual override returns(VersionPart) { return VersionPartLib.toVersionPart(4); }
    function getDomain() public pure virtual override returns(ObjectType) { return REGISTRY(); }
}

contract ServiceMockWithRegistryDomainV5 is ServiceMock 
{
    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner, address initialAuthority)
        ServiceMock(nftId, registryNftId, isInterceptor, initialOwner, initialAuthority)
    {}

    function getRelease() public pure virtual override returns(VersionPart) { return VersionPartLib.toVersionPart(5); }
    function getDomain() public pure virtual override returns(ObjectType) { return REGISTRY(); }
}
