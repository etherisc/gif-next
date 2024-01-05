// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, INSTANCE, SERVICE} from "../../contracts/types/ObjectType.sol";


import {IService} from "../../contracts/instance/base/IService.sol";
import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";
import {DistributionService} from "../../contracts/instance/service/DistributionService.sol";

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceTestBase} from "./RegistryServiceTestBase.sol";

import {InstanceMock,
        InstanceMockWithRandomInvalidType, 
        InstanceMockWithRandomInvalidAddress} from "../mock/InstanceMock.sol";

contract RegisterInstanceTest is RegistryServiceTestBase {

    function setUp() public override
    {
        super.setUp();

        IService componentOwnerService = new ComponentOwnerService(
            address(registry), 
            registryNftId, 
            registryOwner            
        );
        IService productService = new ProductService(
            address(registry), 
            registryNftId, 
            registryOwner  
        );
        IService poolService = new PoolService(
            address(registry), 
            registryNftId, 
            registryOwner  
        );
        IService distributionService = new DistributionService(
            address(registry), 
            registryNftId, 
            registryOwner  
        );

        vm.startPrank(registryOwner);

        registryService.registerService(componentOwnerService);
        registryService.registerService(productService);
        registryService.registerService(poolService);
        registryService.registerService(distributionService);

        vm.stopPrank();
    }

    function test_callByOutsider() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry), 
            registryNftId, 
            outsider);

        vm.prank(outsider);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerInstance(instance);

        _assert_registered_contract(address(instance), info, data);        
    }

    function test_selfRegistration() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.SelfRegistration.selector));

        registryService.registerInstance(IInstance(registryOwner));        
    }

    function test_withEOA() public
    {
        vm.prank(registryOwner);

        vm.expectRevert();

        registryService.registerInstance(IInstance(EOA));
    }

    function test_contractWithoutIERC165() public
    {
        vm.prank(registryOwner);

        vm.expectRevert();

        registryService.registerInstance(IInstance(address(contractWithoutIERC165)));
    }

    function test_withIERC165() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotInstance.selector));

        registryService.registerInstance(IInstance(address(erc165)));
    }

    function test_withIRegisterable() public
    {
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotInstance.selector));

        registryService.registerInstance(IInstance(address(registerableOwnedByRegistryOwner)));
    }

    function test_withIInstance() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry), 
            registryNftId, 
            registryOwner);

        vm.prank(registryOwner);

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerInstance(instance);

        _assert_registered_contract(address(instance), info, data);  
    }

    function test_withInvalidType() public 
    {
        InstanceMockWithRandomInvalidType instance = new InstanceMockWithRandomInvalidType(
            address(registry),
            registryNftId,
            registryOwner
        );

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.UnexpectedRegisterableType.selector,
            INSTANCE(),
            instance._invalidType()));

        vm.prank(registryOwner);

        registryService.registerInstance(instance);
    }

    function test_withInvalidAddress() public 
    {
        InstanceMockWithRandomInvalidAddress instance = new InstanceMockWithRandomInvalidAddress(
            address(registry),
            registryNftId,
            registryOwner
        );

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.UnexpectedRegisterableAddress.selector,
            address(instance),
            instance._invalidAddress()));

        vm.prank(registryOwner);

        registryService.registerInstance(instance);
    }

    function test_whenCallerIsNotInitialOwner() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry),
            registryNftId,
            outsider
        );  
    
        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerInstance(instance);  
    }

    function test_withZeroInitialOwner() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry),
            registryNftId,
            address(0)
        );  

        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerInstance(instance);  
    }

    function test_withRegisteredInitialOwner() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry),
            registryNftId,
            address(registry)
        );  

        vm.prank(address(registry));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.RegisterableOwnerIsRegistered.selector));

        registryService.registerInstance(instance);   
    }

    function test_whenParentIsNotRegistry() public
    {
        InstanceMock instance = new InstanceMock(
            address(registry),
            registryServiceNftId,
            registryOwner
        );  

        vm.prank(registryOwner);

        vm.expectRevert(abi.encodeWithSelector(
            Registry.InvalidTypesCombination.selector,
            INSTANCE(),
            SERVICE()));

        registryService.registerInstance(instance);      
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