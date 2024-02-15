// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart, VersionPartLib} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, SERVICE} from "../../contracts/types/ObjectType.sol";

import {IService} from "../../contracts/shared/IService.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {IRegistryService} from "../../contracts/registry/IRegistryService.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceTestBase, toBool} from "./RegistryServiceTestBase.sol";

import {ServiceMock,
        SelfOwnedServiceMock,
        ServiceMockWithRandomInvalidType, 
        ServiceMockWithRandomInvalidAddress, 
        ServiceMockNewVersion, 
        ServiceMockOldVersion} from "../mock/ServiceMock.sol";


contract RegisterServiceTest is RegistryServiceTestBase {

// TODO
/*
    function test_callByAddressWithAdminRoleHappyCase() public
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId
            registryNftId, 
            toBool(randomNumber(1)), // isInterceptor
            registryOwner);

        // registryOwner is admin
        vm.prank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerService(service);

        _assert_registered_contract(address(service), info, data);        
    }

    function test_callByAddressWithoutAdminRole() public
    {
        // address without any role
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId, 
            toBool(randomNumber(1)), // isInterceptor
            outsider);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector,
            outsider));
        vm.prank(outsider);

        registryService.registerService(service);

        // address with different role (component registrar role)
        service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId, 
            toBool(randomNumber(1)), // isInterceptor
            address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector,
            address(componentOwnerService)));
        vm.prank(address(componentOwnerService));

        registryService.registerService(service);
    }

    function test_selfRegistration() public
    {
        vm.prank(registryOwner);
        vm.expectRevert();

        registryService.registerService(IService(registryOwner));

        // when registryOwner is IService...
        // 1). owns itself -> SelfRegistration
        // 2). owned by somebody else -> NotRegisterableOwner
    }

    function test_withEOA() public
    {
        vm.prank(registryOwner);
        vm.expectRevert();

        registryService.registerService(IService(EOA));
    }

    function test_withoutIERC165Support() public
    {
        vm.prank(registryOwner);        
        vm.expectRevert();

        registryService.registerService(IService(contractWithoutIERC165));
    }

    function test_withIERC165Support() public
    {
        vm.prank(registryOwner);
        vm.expectRevert(abi.encodeWithSelector(IRegistryService.NotService.selector));

        registryService.registerService(IService(erc165));
    }

    function test_withIRegisterable() public
    {
        vm.prank(registryOwner);
        vm.expectRevert(abi.encodeWithSelector(IRegistryService.NotService.selector));

        registryService.registerService(IService(address(registerableOwnedByRegistryOwner)));
    }

    function test_withIServiceHappyCase() public
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId, 
            toBool(randomNumber(1)), // isInterceptor
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
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor
            registryOwner
        );

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.UnexpectedRegisterableType.selector,
            SERVICE(),
            service._invalidType()));

        vm.prank(registryOwner);

        registryService.registerService(service);
    }

    function test_withInvalidAddressHappyCase() public 
    {
        ServiceMockWithRandomInvalidAddress service = new ServiceMockWithRandomInvalidAddress(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
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
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor
            outsider
        );  
    
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerService(service);  
    }

    function test_withZeroInitialOwner() public
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            address(0)
        );  

        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IRegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerService(service);  
    }
    // registryOwner/admin must be initialOwner -> must register itself first
    //function test_withRegisteredInitialOwner() public
    //{
    //    ServiceMock service = new ServiceMock(
    //        toNftId(randomNumber(type(uint96).max)), // nftId 
    //        registryNftId,
    //        toBool(randomNumber(1)), // isInterceptor 
    //        address(registry)
    //    );

    //    vm.prank(registryOwner);

    //    vm.expectRevert(abi.encodeWithSelector(
    //        IRegistryService.RegisterableOwnerIsRegistered.selector));

    //    registryService.registerService(service);  
    //}

    // TODO refactor test
    function test_whenParentIsNotRegistry() public
    {
        // ServiceMock service = new ServiceMock(
        //     toNftId(randomNumber(type(uint96).max)), // nftId 
        //     registryServiceNftId,
        //     toBool(randomNumber(1)), // isInterceptor 
        //     registryOwner
        // ); 

        // vm.prank(registryOwner);

        // vm.expectRevert(abi.encodeWithSelector(
        //     Registry.InvalidTypesCombination.selector,
        //     SERVICE(),
        //     SERVICE()));

        // registryService.registerService(service);         
    }

    function test_whenServiceIsAlreadyRegistered() public
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId, 
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner);

        vm.startPrank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerService(service);

        _assert_registered_contract(address(service), info, data); 

        vm.expectRevert(abi.encodeWithSelector(
            IRegistry.ContractAlreadyRegistered.selector,
            address(service)));

        registryService.registerService(service);

        vm.stopPrank();
    }

    function test_withTooOldVersion() public
    {
        ServiceMockOldVersion service = new ServiceMockOldVersion(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner
        );  

        vm.expectRevert(abi.encodeWithSelector(
            IRegistry.InvalidServiceVersion.selector,
            service.getMajorVersion()));

        vm.prank(registryOwner);

        registryService.registerService(service);  
    }

    function test_withTooNewVersion() public
    {
        ServiceMockNewVersion service = new ServiceMockNewVersion(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner
        );  

        vm.expectRevert(abi.encodeWithSelector(
            IRegistry.InvalidServiceVersion.selector, 
            service.getMajorVersion()));

        vm.prank(registryOwner);

        registryService.registerService(service);  
    }

    function test_withDuplicateName() public 
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner
        );  

        ServiceMock serviceWithDuplicateName = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner
        );  

        vm.startPrank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = registryService.registerService(service);  

        _assert_registered_contract(address(service), info, data);

        vm.expectRevert(abi.encodeWithSelector(
            IRegistry.ServiceNameAlreadyRegistered.selector, 
            service.getName(), service.getMajorVersion()));

        registryService.registerService(serviceWithDuplicateName);  

        vm.stopPrank();
    }

    function test_withNextVersionHappyCase() public
    {
        ServiceMock service = new ServiceMock(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner
        );  

        ServiceMockNewVersion serviceWithNextVersion = new ServiceMockNewVersion(
            toNftId(randomNumber(type(uint96).max)), // nftId 
            registryNftId,
            toBool(randomNumber(1)), // isInterceptor 
            registryOwner            
        );

        vm.startPrank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = registryService.registerService(service); 

        _assert_registered_contract(address(service), info, data);

        // attempt to register service for major release > getMajorVersion()
        VersionPart majorVersion4 = VersionPartLib.toVersionPart(4);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.InvalidServiceVersion.selector,
                majorVersion4));
        registryService.registerService(serviceWithNextVersion);

        // increase major version to 4 and retry (expected outcome: registration does not revert)
        registry.setMajorVersion(majorVersion4);
        (
            info,
            data
        ) = registryService.registerService(serviceWithNextVersion);

        _assert_registered_contract(address(serviceWithNextVersion), info, data);

        vm.stopPrank();
    }
*/
}