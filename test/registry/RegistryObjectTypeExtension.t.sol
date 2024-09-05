// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/upgradeability/IVersionable.sol";

import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {Version, VersionLib, VersionPart} from "../../contracts/type/Version.sol";


function FOO_PLAIN_REGISTRY() pure returns (ObjectType) { return ObjectType.wrap(50); }
function FOO_CONTRACT_REGISTRY() pure returns (ObjectType) { return ObjectType.wrap(51); }
function FOO_INSTANCE() pure returns (ObjectType) { return ObjectType.wrap(52); }
function BAR_FOO() pure returns (ObjectType) { return ObjectType.wrap(53); }


contract RegistryServiceUpgraded is RegistryService {

    /// all version upgrades must implement this function
    /// see Versionable.sol for more details
    function _initialize(address owner, bytes memory data)
        internal
        onlyInitializing
        virtual override
    { 
        // super._initialize(owner, data);
    }

    /// all version upgrades must implement this function
    /// see Versionable.sol for more details
    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual override
    { }

    function getVersion() public pure virtual override (IVersionable, Service) returns(Version) {
        return VersionLib.toVersion(3, 1, 0);
    }

    /// @dev permissionless registry function for testing
    function register(IRegistry.ObjectInfo memory info) external virtual returns (NftId nftId) {
        getRegistry().register(info);
    }

    /// @dev permissionless registry function for testing
    function registerWithCustomType(IRegistry.ObjectInfo memory info) external virtual returns (NftId nftId) {
        getRegistry().registerWithCustomType(info);
    }
}


contract RegistryObjectTypeExtensionTest is GifTest {

    RegistryServiceUpgraded public registryServiceUpgraded;

    function setUp() public override {
        super.setUp();
        registryServiceUpgraded = _upgradeRegistryService();
    }


    function test_registryObjectTypeExtensionSetup() public view {
        (VersionPart major, VersionPart minor, VersionPart patch) = registryServiceManager.getVersion().toVersionParts();
        // solhiint-disable next-line
        console.log("registry service version (major, minor, patch)", major.toInt(), minor.toInt(), patch.toInt());
        assertEq(major.toInt(), 3);
        assertEq(minor.toInt(), 1);
        assertEq(patch.toInt(), 0);
    }


    function test_registryObjectTypeExtensionRegisterFooPlainHappyCase() public {
        vm.startPrank(outsider);
        NftId fooNftId = registryServiceUpgraded.register(
            _toPlainObjectInfo(registryNftId, FOO_PLAIN_REGISTRY()));
        vm.stopPrank();
    }


    function _toPlainObjectInfo(NftId parentNftId, ObjectType objectType) internal view returns (IRegistry.ObjectInfo memory info) {
        return _toObjectInfo(parentNftId, objectType, address(0));
    }


    function _toObjectInfo(NftId parentNftId, ObjectType objectType, address contractAddress) internal view returns (IRegistry.ObjectInfo memory info) {
        return IRegistry.ObjectInfo({
            nftId: NftId.wrap(0),
            parentNftId: parentNftId,
            objectType: objectType,
            isInterceptor: false,
            objectAddress: contractAddress,
            initialOwner: msg.sender,
            data: ""
        });
    }

    function _upgradeRegistryService() internal returns (RegistryServiceUpgraded) {
        address regSvcUpd = address(new RegistryServiceUpgraded());
        bytes memory emptyUpgradeData;

        vm.prank(registryOwner);
        registryServiceManager.upgrade(address(regSvcUpd), emptyUpgradeData);

        return RegistryServiceUpgraded(regSvcUpd);
    }
}