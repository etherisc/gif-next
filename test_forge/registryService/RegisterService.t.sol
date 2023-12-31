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
        SelfOwnedServiceMock,
        ServiceMockWithRandomInvalidType, 
        ServiceMockWithRandomInvalidAddress, 
        ServiceMockNewVersion, 
        ServiceMockOldVersion} from "../mock/ServiceMock.sol";


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

        vm.expectRevert();
        registryService.registerService(IService(registryOwner));

        vm.prank(outsider);

        vm.expectRevert();

        registryService.registerService(IService(outsider));    

        ServiceMock service = new ServiceMock(
            address(registry), 
            registryNftId, 
            registryOwner);

        vm.prank(address(service));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(service)));

        registryService.registerService(service);  

        SelfOwnedServiceMock selfOwnedService = new SelfOwnedServiceMock(
            address(registry), 
            registryNftId);

        vm.prank(address(selfOwnedService));

        vm.expectRevert(abi.encodeWithSelector(RegistryService.SelfRegistration.selector));

        registryService.registerService(selfOwnedService);  
    }

    function test_withEOA() public
    {
        vm.expectRevert();

        registryService.registerService(IService(EOA));
    }

    function test_contractWithoutIERC165() public
    {
        vm.expectRevert();

        registryService.registerService(IService(contractWithoutIERC165));
    }

    function test_withIERC165() public
    {
        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotService.selector));

        registryService.registerService(IService(erc165));
    }

    function test_withIRegisterable() public
    {
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

        _assert_registered_contract(address(service), info, data);
    }

    function test_withInvalidType() public 
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

    function test_withInvalidAddress() public 
    {
        ServiceMockWithRandomInvalidAddress service = new ServiceMockWithRandomInvalidAddress(
            address(registry),
            registryNftId,
            registryOwner
        );

        vm.prank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerService(service);

        _assert_registered_contract(address(service), info, data);
    }

    function test_whenCallerIsNotInitialOwner() public
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

    function test_withRegisteredInitialOwner() public
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryNftId,
            address(registry)
        );

        vm.prank(address(registry));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.RegisterableOwnerIsRegistered.selector));

        registryService.registerService(service);  
    }

    function test_whenParentIsNotRegistry() public
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryServiceNftId,
            registryOwner
        ); 

        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            Registry.InvalidTypesCombination.selector,
            SERVICE(),
            SERVICE()));

        registryService.registerService(service);         
    }

    function test_withTooOldVersion() public
    {
        ServiceMockOldVersion service = new ServiceMockOldVersion(
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
        ServiceMockNewVersion service = new ServiceMockNewVersion(
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

    function test_withDuplicateName() public 
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryNftId,
            registryOwner
        );  

        ServiceMock duplicateService = new ServiceMock(
            address(registry),
            registryNftId,
            registryOwner
        );  

        vm.startPrank(registryOwner);

        registryService.registerService(service);  

        vm.expectRevert(abi.encodeWithSelector(
            Registry.ServiceNameAlreadyRegistered.selector, 
            service.getName(), service.getMajorVersion()));

        registryService.registerService(duplicateService);  

        vm.stopPrank();
    }

    function test_withNextVersion() public
    {
        ServiceMock service = new ServiceMock(
            address(registry),
            registryNftId,
            registryOwner
        );  

        ServiceMockNewVersion newService = new ServiceMockNewVersion(
            address(registry),
            registryNftId,
            registryOwner            
        );

        vm.startPrank(registryOwner);

        registryService.registerService(service);

        registryService.registerService(newService);

        vm.stopPrank();
    }
}