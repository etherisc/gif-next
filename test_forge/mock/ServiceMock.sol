// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId} from "../../contracts/types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {ObjectType, toObjectType, SERVICE, PRODUCT, POOL, ORACLE, DISTRIBUTION} from "../../contracts/types/ObjectType.sol";
import {IService} from "../../contracts/shared/IService.sol";
import {RegisterableMock} from "./RegisterableMock.sol";

contract ServiceMock is RegisterableMock, IService {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner)
        RegisterableMock(
            nftId,
            registryNftId,
            SERVICE(),
            isInterceptor,
            initialOwner,
            "")
    {
        _info.data = abi.encode(getDomain(), getMajorVersion());
        registerInterface(type(IService).interfaceId);
    }

    // from IService
    function getDomain() public pure virtual returns(ObjectType) {
        return PRODUCT();
    }

    function getMajorVersion() public view virtual override returns(VersionPart majorVersion) {
        return getVersion().toMajorPart(); 
    }

    // from IVersionable
    function getVersion()
        public 
        pure 
        virtual override// (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }
    
    // from IVersionable, DON NOT USE
    function initializeVersionable(address activatedBy, bytes memory activationData) external { revert(); }
    function upgradeVersionable(bytes memory upgradeData) external { revert(); }
}

contract SelfOwnedServiceMock is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor)
        ServiceMock(
            nftId, 
            registryNftId, 
            isInterceptor, 
            address(this))
    {}

    function getDomain() public pure override returns(ObjectType) {
        return DISTRIBUTION();
    }
}

contract ServiceMockWithRandomInvalidType is ServiceMock {

    ObjectType public immutable _invalidType;

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner)
    {
        FoundryRandom rng = new FoundryRandom();

        ObjectType invalidType = toObjectType(rng.randomNumber(type(uint96).max));
        if(invalidType == SERVICE()) {
            invalidType = toObjectType(invalidType.toInt() + 1);
        }

        _info.objectType = invalidType;
        _invalidType = invalidType;
    }

    function getDomain() public pure override returns(ObjectType) {
        return ORACLE();
    }
}

contract ServiceMockWithRandomInvalidAddress is ServiceMock {

    address public immutable _invalidAddress;

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner)
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

}

contract ServiceMockOldVersion is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner)
    {}

    function getDomain() public pure override returns(ObjectType) {
        return PRODUCT(); // same as ServiceMock
    }

    function getVersion() public pure override returns(Version)
    {
        return VersionLib.toVersion(2,0,0);
    }
}

contract ServiceMockNewVersion is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor, address initialOwner)
        ServiceMock(
            nftId,
            registryNftId,
            isInterceptor,
            initialOwner)
    {}

    function getDomain() public pure override returns(ObjectType) {
        return PRODUCT(); // same as ServiceMock
    }

    function getVersion() public pure override returns(Version)
    {
        return VersionLib.toVersion(4,0,0);
    }
}