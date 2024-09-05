// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IVersionable} from "../../contracts/upgradeability/IVersionable.sol";

import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, INSTANCE, REGISTRY, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {Version, VersionLib, VersionPart} from "../../contracts/type/Version.sol";


function FOO_PLAIN() pure returns (ObjectType) { return ObjectType.wrap(50); }
function FOO_CONTRACT() pure returns (ObjectType) { return ObjectType.wrap(51); }
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
        return getRegistry().register(info);
    }

    /// @dev permissionless registry function for testing
    function registerWithCustomType(IRegistry.ObjectInfo memory info) external virtual returns (NftId nftId) {
        return getRegistry().registerWithCustomType(info);
    }
}


contract RegistryObjectTypeExtensionTest is GifTest {

    RegistryServiceUpgraded public registryServiceUpgraded;

    function setUp() public override {
        super.setUp();

        (VersionPart major, VersionPart minor, VersionPart patch) = registryService.getVersion().toVersionParts();

        // solhiint-disable
        console.log("registry service registry [before]", address(registryService.getRegistry()));
        console.log("registry service version [before] (major, minor, patch)", major.toInt(), minor.toInt(), patch.toInt());
        // solhint-enable

        registryServiceUpgraded = _upgradeRegistryService();

        (major, minor, patch) = registryService.getVersion().toVersionParts();
        // solhiint-disable
        console.log("registry service registry [after]", address(registryService.getRegistry()));
        console.log("registry service version [after] (major, minor, patch)", major.toInt(), minor.toInt(), patch.toInt());
        // solhint-enable
    }


    function test_registryObjectTypeExtensionSetup() public {
        (VersionPart major, VersionPart minor, VersionPart patch) = registryService.getVersion().toVersionParts();
        assertEq(major.toInt(), 3);
        assertEq(minor.toInt(), 1);
        assertEq(patch.toInt(), 0);
    }


    function test_registryObjectTypeExtensionRegisterFooWithRegistryParentHappyCase() public {
        // GIVEN

        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(registryNftId, FOO_PLAIN(), outsider);

        // WHEN
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfo = registry.getObjectInfo(fooNftId);
        assertEq(fooInfo.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfo.parentNftId.toInt(), registryNftId.toInt(), "parentNftId is not registryNftId");
        assertEq(fooInfo.objectType.toInt(), FOO_PLAIN().toInt(), "unexpected objectType");
        assertFalse(fooInfo.isInterceptor, "isInterceptor is true");
        assertEq(fooInfo.objectAddress, address(0), "unexpected objectAddress");
        assertEq(fooInfo.initialOwner, outsider, "unexpected initialOwner");
        assertEq(fooInfo.data.length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev attempt to register foo type with global registry as parent (when on mainet)
    function test_registryObjectTypeExtensionRegisterFooWithGlobalRegistryParentHappyCase() public {
        // GIVEN
        NftId globalRegistryNftId = registry.getParentNftId(registryNftId);
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(globalRegistryNftId, FOO_PLAIN(), outsider);

        assertEq(globalRegistryNftId.toInt(), 2101, "unexpected globalRegistryNftId");

        // WHEN
        vm.chainId(1);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfo = registry.getObjectInfo(fooNftId);
        assertEq(fooInfo.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfo.parentNftId.toInt(), globalRegistryNftId.toInt(), "parentNftId is not globalRegistryNftId");
        assertEq(fooInfo.objectType.toInt(), FOO_PLAIN().toInt(), "unexpected objectType");
        assertFalse(fooInfo.isInterceptor, "isInterceptor is true");
        assertEq(fooInfo.objectAddress, address(0), "unexpected objectAddress");
        assertEq(fooInfo.initialOwner, outsider, "unexpected initialOwner");
        assertEq(fooInfo.data.length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev attempt to register foo type with instance as parent (when on mainet)
    function test_registryObjectTypeExtensionRegisterFooWithInstanceParentHappyCase() public {
        // GIVEN
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(instanceNftId, FOO_PLAIN(), outsider);

        assertEq(instance.getNftId().toInt(), instanceNftId.toInt(), "unexpected instanceNftId");

        // WHEN
        vm.chainId(1);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfo = registry.getObjectInfo(fooNftId);
        assertEq(fooInfo.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfo.parentNftId.toInt(), instanceNftId.toInt(), "parentNftId is not instanceNftId");
        assertEq(fooInfo.objectType.toInt(), FOO_PLAIN().toInt(), "unexpected objectType");
        assertFalse(fooInfo.isInterceptor, "isInterceptor is true");
        assertEq(fooInfo.objectAddress, address(0), "unexpected objectAddress");
        assertEq(fooInfo.initialOwner, outsider, "unexpected initialOwner");
        assertEq(fooInfo.data.length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev attempt to register foo type with staking as parent 
    function test_registryObjectTypeExtensionRegisterFooWithStakingParent() public {
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(staking.getNftId(), FOO_PLAIN(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryTypeCombinationInvalid.selector, fooInfoIn.objectAddress, fooInfoIn.objectType, STAKING()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);
    }


    /// @dev attempt to register foo type with global registry as parent (when not on mainet)
    function test_registryObjectTypeExtensionRegisterFooWithGlobalRegistryParentNotMainnet() public {
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(registry.getParentNftId(registryNftId), FOO_PLAIN(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, fooInfoIn.objectAddress, fooInfoIn.objectType));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);
    }


    /// @dev attempt to register instance type via core type register()
    function test_registryObjectTypeExtensionRegisterFooViaRegister() public {
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(registryNftId, FOO_PLAIN(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryTypeCombinationInvalid.selector, fooInfoIn.objectAddress, fooInfoIn.objectType, REGISTRY()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.register(fooInfoIn);
    }


    /// @dev attempt to register instance type via core type register()
    function test_registryObjectTypeExtensionRegisterInstanceViaRegisterWithCustomType() public {
        IRegistry.ObjectInfo memory fooInfoIn = _toPlainObjectInfo(instanceNftId, INSTANCE(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryCoreTypeRegistration.selector));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfoIn);
    }


    function _toPlainObjectInfo(NftId parentNftId, ObjectType objectType, address owner) internal view returns (IRegistry.ObjectInfo memory info) {
        return _toObjectInfo(parentNftId, objectType, owner, address(0));
    }


    function _toObjectInfo(NftId parentNftId, ObjectType objectType, address owner, address contractAddress) internal view returns (IRegistry.ObjectInfo memory info) {
        return IRegistry.ObjectInfo({
            nftId: NftId.wrap(0),
            parentNftId: parentNftId,
            objectType: objectType,
            isInterceptor: false,
            objectAddress: contractAddress,
            initialOwner: owner,
            data: ""
        });
    }


    function _upgradeRegistryService() internal returns (RegistryServiceUpgraded regSvcUpd) {
        vm.startPrank(registryOwner);
        registryServiceManager.upgrade(address(new RegistryServiceUpgraded()));
        vm.stopPrank();

        return RegistryServiceUpgraded(address(registryService));
    }
}