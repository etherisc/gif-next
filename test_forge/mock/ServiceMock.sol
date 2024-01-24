// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {NftId} from "../../contracts/types/NftId.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";
import {ObjectType, toObjectType, SERVICE} from "../../contracts/types/ObjectType.sol";
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
        _info.data = abi.encode(getName(), getMajorVersion());
        _registerInterface(type(IService).interfaceId);
    }

    // from IService
    function getName() public pure virtual override returns(string memory name) {
        return "ServiceMock";
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
    function initialize(address implementation, address activatedBy, bytes memory activationData) external { revert(); }
    function upgrade(address implementation, address activatedBy, bytes memory upgradeData) external { revert(); }
    function isInitialized(Version version) external view returns(bool) { revert(); }
    function getVersionCount() external view returns(uint256 numberOfVersions) { revert(); }
    function getVersion(uint256 index) external view returns(Version version) { revert(); }
    function getVersionInfo(Version version) external view returns(VersionInfo memory versionInfo) { revert(); }
    function getInitializedVersion() external view returns(uint64) { revert(); }
}

contract SelfOwnedServiceMock is ServiceMock {

    constructor(NftId nftId, NftId registryNftId, bool isInterceptor)
        ServiceMock(
            nftId, 
            registryNftId, 
            isInterceptor, 
            address(this))
    {}

    function getName() public pure override returns(string memory name) {
        return "SelfOwnedServiceMock";
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

    function getName() public pure override returns(string memory name) {
        return "ServiceMockWithRandomInvalidType";
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

    function getName() public pure override returns(string memory name) {
        return "ServiceMockWithRandomInvalidAddress";
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

    function getName() public pure override returns(string memory name) {
        return "ServiceMock"; // same name as ServiceMock
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

    function getName() public pure override returns(string memory name) {
        return "ServiceMock";// same name as ServiceMock
    }

    function getVersion() public pure override returns(Version)
    {
        return VersionLib.toVersion(4,0,0);
    }
}