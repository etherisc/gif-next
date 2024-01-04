// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, SERVICE} from "../../contracts/types/ObjectType.sol";

import {IService} from "../../contracts/instance/base/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceTestBase} from "./RegistryServiceTestBase.sol";

import {ServiceMock, 
        ServiceMockWithRandomInvalidType, 
        ServiceMockWithRandomInvalidAddress, 
        ServiceMockWithTooNewVersion, 
        ServiceMockWithTooOldVersion} from "../mock/ServiceMock.sol";

// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) /*&&
        (a.data == b.data)*/
    );
}

function zeroObjectInfo() pure returns (IRegistry.ObjectInfo memory) {
    return (
        IRegistry.ObjectInfo(
            zeroNftId(),
            zeroNftId(),
            zeroObjectType(),
            false,
            address(0),
            address(0),
            bytes("")
        )
    );
}

contract RegisterServiceTest is RegistryServiceTestBase {

    function test_callByOutsider() public
    {
        ServiceMock service = new ServiceMock(
            address(registry), 
            registryNftId, 
            outsider);

        vm.prank(outsider);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotRegistryOwner.selector)); 

        registryService.registerService(service);        
    }

    function test_selfRegistration() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.SelfRegistration.selector));

        registryService.registerService(IService(registryOwner));        
    }

    function test_withEOA() public
    {
        vm.prank(registryOwner);

        vm.expectRevert();

        registryService.registerService(IService(EOA));
    }

    function test_contractWithoutIERC165() public
    {
        vm.prank(registryOwner);

        vm.expectRevert();

        registryService.registerService(IService(address(contractWithoutIERC165)));
    }

    function test_withIERC165() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotService.selector));

        registryService.registerService(IService(address(erc165)));
    }

    function test_withIRegisterable() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotService.selector));

        registryService.registerService(IService(address(registerableOwnedByRegistryOwner)));
    }

    function test_withIService() public
    {
        ServiceMock service = new ServiceMock(
            address(registry), 
            registryNftId, 
            registryOwner);

        vm.prank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerService(service);

        IRegistry.ObjectInfo memory infoFromRegistry = registry.getObjectInfo(info.nftId);
        (
            IRegistry.ObjectInfo memory infoFromService,
            bytes memory dataFromService
        ) = service.getInitialInfo();

        assertTrue(eqObjectInfo(infoFromRegistry, info), "Invalid info returned #1");
        assertTrue(eqObjectInfo(infoFromRegistry, infoFromService), "Invalid info returned #2");
        assertEq(data, dataFromService, "Invalid data returned");
    }

    function test_withInvalidObjectType() public 
    {
        ServiceMockWithRandomInvalidType service = new ServiceMockWithRandomInvalidType(
            address(registry),
            registryNftId,
            registryOwner
        );

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.UnexpectedRegisterableType.selector,
            SERVICE(),
            service._invalidType()));

        vm.prank(registryOwner);

        registryService.registerService(service);
    }

    function test_withInvalidObjectAddress() public 
    {
        ServiceMockWithRandomInvalidAddress service = new ServiceMockWithRandomInvalidAddress(
            address(registry),
            registryNftId,
            registryOwner
        );

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.UnexpectedRegisterableAddress.selector,
            address(service),
            service._invalidAddress()));

        vm.prank(registryOwner);

        registryService.registerService(service);
    }

    function test_whenNotInitialOwner() public
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryNftId,
            outsider
        );  
    
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerService(service);  
    }

    function test_withZeroInitialOwner() public
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryNftId,
            address(0)
        );  

        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerService(service);  
    }

    function test_withTooOldVersion() public
    {
        ServiceMockWithTooOldVersion service = new ServiceMockWithTooOldVersion(
            address(registry),
            registryNftId,
            registryOwner
        );  

        vm.expectRevert(abi.encodeWithSelector(
            Registry.InvalidServiceVersion.selector,
            service.getMajorVersion()));

        vm.prank(registryOwner);

        registryService.registerService(service);  
    }

    function test_withTooNewVersion() public
    {
        ServiceMockWithTooNewVersion service = new ServiceMockWithTooNewVersion(
            address(registry),
            registryNftId,
            registryOwner
        );  

        vm.expectRevert(abi.encodeWithSelector(
            Registry.InvalidServiceVersion.selector, 
            service.getMajorVersion()));

        vm.prank(registryOwner);

        registryService.registerService(service);  
    }

    function test_registerDuplicateServiceName() public 
    {
        ServiceMock service_1 = new ServiceMock(
            address(registry),
            registryNftId,
            registryOwner
        );  

        ServiceMock service_2 = new ServiceMock(
            address(registry),
            registryNftId,
            registryOwner
        );  

        vm.startPrank(registryOwner);

        registryService.registerService(service_1);  

        vm.expectRevert(abi.encodeWithSelector(
            Registry.ServiceNameAlreadyRegistered.selector, 
            service_1.getName(), service_1.getMajorVersion()));

        registryService.registerService(service_2);  
    }
}

/*
        NftId nftId;
        NftId parentNftId;
        ObjectType objectType;
        bool isInterceptor;
        address objectAddress;
        address initialOwner;
        bytes data;
        */