// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../lib/forge-std/src/Test.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IUpgradeable} from "../../contracts/upgradeability/IUpgradeable.sol";
import {IVersionable} from "../../contracts/shared/IVersionable.sol";

import {GifTest} from "../base/GifTest.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectType, INSTANCE, REGISTRY, SERVICE, STAKING} from "../../contracts/type/ObjectType.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {Service} from "../../contracts/shared/Service.sol";
import {Version, VersionLib, VersionPart} from "../../contracts/type/Version.sol";


function FOO() pure returns (ObjectType) { return ObjectType.wrap(50); }
function BAR_FOO() pure returns (ObjectType) { return ObjectType.wrap(51); }


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
    function register(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) external virtual returns (NftId nftId) {
        return getRegistry().register(info, initialOwner, data);
    }

    /// @dev permissionless registry function for testing
    function registerWithCustomType(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) external virtual returns (NftId nftId) {
        return getRegistry().registerWithCustomType(info, initialOwner, data);
    }
}


contract RegistryObjectTypeExtensionTest is GifTest {

    RegistryServiceUpgraded public registryServiceUpgraded;
    bytes public emptyData;

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

    //--- check foo type object registration with expected parent types --------------------------------------------//

    /// @dev register foo type object with REGISTRY as parent
    function test_registryObjectTypeExtensionRegisterFooWithRegistryParentHappyCase() public {
        // GIVEN
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(registryNftId, FOO(), outsider);

        // WHEN
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfoOut = registry.getObjectInfo(fooNftId);
        assertEq(fooInfoOut.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfoOut.parentNftId.toInt(), registryNftId.toInt(), "parentNftId is not registryNftId");
        assertEq(fooInfoOut.objectType.toInt(), FOO().toInt(), "unexpected objectType");
        assertFalse(fooInfoOut.isInterceptor, "isInterceptor is true");
        assertEq(fooInfoOut.objectAddress, fooInfo.objectAddress, "unexpected objectAddress");
        assertEq(registry.getObjectData(fooNftId).length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev register foo type object with global REGISTRY as parent (when on mainet)
    function test_registryObjectTypeExtensionRegisterFooWithGlobalRegistryParentHappyCase() public {
        // GIVEN
        NftId globalRegistryNftId = registry.getParentNftId(registryNftId);
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(globalRegistryNftId, FOO(), outsider);
        assertEq(globalRegistryNftId.toInt(), 2101, "unexpected globalRegistryNftId");

        // WHEN
        vm.chainId(1);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfoOut = registry.getObjectInfo(fooNftId);
        assertEq(fooInfoOut.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfoOut.parentNftId.toInt(), globalRegistryNftId.toInt(), "parentNftId is not globalRegistryNftId");
        assertEq(fooInfoOut.objectType.toInt(), FOO().toInt(), "unexpected objectType");
        assertFalse(fooInfoOut.isInterceptor, "isInterceptor is true");
        assertEq(fooInfoOut.objectAddress, fooInfo.objectAddress, "unexpected objectAddress");
        assertEq(registry.getObjectData(fooNftId).length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev register foo type object with INSTANCE as parent
    function test_registryObjectTypeExtensionRegisterFooWithInstanceParentHappyCase() public {
        // GIVEN
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(instanceNftId, FOO(), outsider);
        assertEq(instance.getNftId().toInt(), instanceNftId.toInt(), "unexpected instanceNftId");

        // WHEN
        vm.chainId(1);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfoOut = registry.getObjectInfo(fooNftId);
        assertEq(fooInfoOut.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfoOut.parentNftId.toInt(), instanceNftId.toInt(), "parentNftId is not instanceNftId");
        assertEq(fooInfoOut.objectType.toInt(), FOO().toInt(), "unexpected objectType");
        assertFalse(fooInfoOut.isInterceptor, "isInterceptor is true");
        assertEq(fooInfoOut.objectAddress, fooInfo.objectAddress, "unexpected objectAddress");
        assertEq(registry.getObjectData(fooNftId).length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }


    /// @dev register foo type object with PRODUCT as parent
    function test_registryObjectTypeExtensionRegisterFooWithProductParentHappyCase() public {
        // GIVEN
        _prepareProduct();  
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(productNftId, FOO(), outsider);
        assertEq(product.getNftId().toInt(), productNftId.toInt(), "unexpected productNftId");

        // WHEN
        vm.chainId(1);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);

        // THEN
        assertTrue(fooNftId.gtz(), "fooNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory fooInfoOut = registry.getObjectInfo(fooNftId);
        assertEq(fooInfoOut.nftId.toInt(), fooNftId.toInt(), "unexpected nftId");
        assertEq(fooInfoOut.parentNftId.toInt(), productNftId.toInt(), "parentNftId is not productNftId");
        assertEq(fooInfoOut.objectType.toInt(), FOO().toInt(), "unexpected objectType");
        assertFalse(fooInfoOut.isInterceptor, "isInterceptor is true");
        assertEq(fooInfoOut.objectAddress, fooInfo.objectAddress, "unexpected objectAddress");
        assertEq(registry.getObjectData(fooNftId).length, 0, "unexpected data length");
        assertEq(registry.ownerOf(fooNftId), outsider, "unexpected owner");
    }

    //--- check bar type object registration with foo parent type ----------------------------------------------------//

    /// @dev register bar type object with FOO as parent
    function test_registryObjectTypeExtensionRegisterBarWithFooParentHappyCase() public {
        // GIVEN - foo object with product as parent
        _prepareProduct();  
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(productNftId, FOO(), outsider);
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);

        // WHEN - create bar object with foo as parent
        IRegistry.ObjectInfo memory barInfo;
        address barOwner;
        bytes memory barData;
        (barInfo, barOwner, barData) = _toPlainObjectInfo(fooNftId, BAR_FOO(), outsider);
        // modify object address to ensure it is not the same as foo object
        barInfo.objectAddress = address(123);

        vm.prank(outsider);
        NftId barNftId = registryServiceUpgraded.registerWithCustomType(barInfo, barOwner, barData);

        // THEN
        assertTrue(barNftId.gtz(), "barNftId is zero");

        // check object info
        IRegistry.ObjectInfo memory barInfoOut = registry.getObjectInfo(barNftId);
        assertEq(barInfoOut.nftId.toInt(), barNftId.toInt(), "unexpected nftId");
        assertEq(barInfoOut.parentNftId.toInt(), fooNftId.toInt(), "parentNftId is not fooNftId");
        assertEq(barInfoOut.objectType.toInt(), BAR_FOO().toInt(), "unexpected objectType");
        assertFalse(barInfoOut.isInterceptor, "isInterceptor is true");
        assertEq(barInfoOut.objectAddress, address(123), "unexpected objectAddress");
        assertEq(registry.getObjectData(barNftId).length, 0, "unexpected data length");
        assertEq(registry.ownerOf(barNftId), outsider, "unexpected owner");

        _printObjectHierarchy(barNftId);
    }

    //--- check foo type object registration reverts with unsupported parent types -----------------------------------//


    /// @dev attempt to register foo type object with global REGISTRY as parent (when not on mainet)
    function test_registryObjectTypeExtensionRegisterFooWithGlobalRegistryParentNotMainnet() public {
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(registry.getParentNftId(registryNftId), FOO(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, fooInfo.objectAddress, fooInfo.objectType));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);
    }


    /// @dev attempt to register foo type object with STAKING as parent 
    function test_registryObjectTypeExtensionRegisterFooWithStakingParent() public {
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(staking.getNftId(), FOO(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryTypeCombinationInvalid.selector, fooInfo.objectAddress, fooInfo.objectType, STAKING()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData) ;
    }


    /// @dev attempt to register foo type object with SERVICE as parent 
    function test_registryObjectTypeExtensionRegisterFooWithServiceParent() public {
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(registryService.getNftId(), FOO(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryTypeCombinationInvalid.selector, fooInfo.objectAddress, fooInfo.objectType, SERVICE()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);
    }

    //---- check custom type object registration with mismatching release versions -----------------------------------//

    function test_registryObjectTypeExtensionRegisterFooWithReleaseTooSmall() public 
    {
        (
            product,
            productNftId
        ) = _deployAndRegisterNewSimpleProduct("TestProduct");

        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(productNftId, FOO(), outsider);
        fooInfo.release = VersionPart.wrap(2);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryReleaseMismatch.selector, fooInfo.release, product.getRelease(), registryServiceUpgraded.getRelease()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);
    }

    function test_registryObjectTypeExtensionRegisterFooWithReleaseTooBig() public
    {
        (
            product,
            productNftId
        ) = _deployAndRegisterNewSimpleProduct("TestProduct");

        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(productNftId, FOO(), outsider);
        fooInfo.release = VersionPart.wrap(4);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryReleaseMismatch.selector, fooInfo.release, product.getRelease(), registryServiceUpgraded.getRelease()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);
    }

    //--- check some corner cases -----------------------------------------------------------------------------------//

    /// @dev attempt to register foo type via core type register()
    function test_registryObjectTypeExtensionRegisterFooViaRegister() public {
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(registryNftId, FOO(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryTypeCombinationInvalid.selector, fooInfo.objectAddress, fooInfo.objectType, REGISTRY()));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.register(fooInfo, fooOwner, fooData);
    }

    /// @dev attempt to register instance type via core type register()
    function test_registryObjectTypeExtensionRegisterInstanceViaRegisterWithCustomType() public {
        IRegistry.ObjectInfo memory fooInfo;
        address fooOwner;
        bytes memory fooData;
        (fooInfo, fooOwner, fooData) = _toPlainObjectInfo(instanceNftId, INSTANCE(), outsider);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.ErrorRegistryCoreTypeRegistration.selector));
        vm.prank(outsider);
        NftId fooNftId = registryServiceUpgraded.registerWithCustomType(fooInfo, fooOwner, fooData);
    }

    //--- helper functions -----------------------------------------------------------------------------------------//

    function _toPlainObjectInfo(NftId parentNftId, ObjectType objectType, address owner) internal view returns (IRegistry.ObjectInfo memory, address, bytes memory) {
        return (
            IRegistry.ObjectInfo({
                nftId: NftId.wrap(0),
                parentNftId: parentNftId,
                objectType: objectType,
                release: VersionPart.wrap(3),
                isInterceptor: false,
                objectAddress: address(123456789)
            }),
            owner,
            emptyData
        );
    }


    function _upgradeRegistryService() internal returns (RegistryServiceUpgraded regSvcUpd) {
        vm.startPrank(registryOwner);
        registryServiceManager.upgrade(address(new RegistryServiceUpgraded()));
        vm.stopPrank();

        return RegistryServiceUpgraded(address(registryService));
    }


    function _printObjectHierarchy(NftId nftId) internal view {
        // solhint-disable
        console.log("");
        console.log("object hierarchy for nftId", nftId.toInt());
        console.log("nftId parentNftId objectType objectAddress");
        // solhint-enable

        _printObjectHierarchyInternal(nftId);
    }


    function _printObjectHierarchyInternal(NftId nftId) internal view {
        if (nftId.gtz() && nftId.toInt() != 2101) {
            _printObjectHierarchyInternal(registry.getParentNftId(nftId));
        }

        IRegistry.ObjectInfo memory info = registry.getObjectInfo(nftId);
        // solhint-disable next-line
        console.log(nftId.toInt(), info.parentNftId.toInt(), info.objectType.toInt(), info.objectAddress);
    }
}