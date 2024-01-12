// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Vm, console} from "../../lib/forge-std/src/Test.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, ObjectTypeLib, SERVICE, INSTANCE, PRODUCT} from "../../contracts/types/ObjectType.sol";
import {PRODUCT_REGISTRAR_ROLE, POOL_REGISTRAR_ROLE, DISTRIBUTION_REGISTRAR_ROLE, POLICY_REGISTRAR_ROLE, BUNDLE_REGISTRAR_ROLE} from "../../contracts/types/RoleId.sol";

import {IService} from "../../contracts/instance/base/IService.sol";
import {ComponentOwnerService} from "../../contracts/instance/service/ComponentOwnerService.sol";
import {ProductService} from "../../contracts/instance/service/ProductService.sol";
import {PoolService} from "../../contracts/instance/service/PoolService.sol";
import {DistributionService} from "../../contracts/instance/service/DistributionService.sol";

import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceTestBase, toBool} from "./RegistryServiceTestBase.sol";

import {InstanceMock} from "../mock/InstanceMock.sol";
import {ProductMock,
        SelfOwnedProductMock,
        ProductMockWithRandomInvalidType, 
        ProductMockWithRandomInvalidAddress} from "../mock/ProductMock.sol";

contract RegisterProductTest is RegistryServiceTestBase {

    address instanceOwner = makeAddr("instanceOwner");
    address productOwner = makeAddr("productOwner");
    
    IService componentOwnerService;

    NftId instanceNftId;

    function setUp() public override
    {
        super.setUp();

        vm.startPrank(registryOwner);

        _configureAccessManagerRoles();

        _registerServices();

        vm.stopPrank();

        InstanceMock instance = new InstanceMock(
            address(registry), 
            registryNftId, 
            instanceOwner);

        vm.prank(instanceOwner);

        registryService.registerInstance(instance);

        instanceNftId = registry.getNftId(address(instance));
    }

    function _configureAccessManagerRoles() internal
    {
        bytes4[] memory functionSelector = new bytes4[](1);
        functionSelector[0] = RegistryService.registerProduct.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            PRODUCT_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerPool.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            POOL_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerDistribution.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            DISTRIBUTION_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerPolicy.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            POLICY_REGISTRAR_ROLE().toInt());

        functionSelector[0] = RegistryService.registerBundle.selector;

        accessManager.setTargetFunctionRole(
            address(registryService), 
            functionSelector, 
            BUNDLE_REGISTRAR_ROLE().toInt());
    }

    function _registerServices() internal
    {
        componentOwnerService = new ComponentOwnerService(
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

        registryService.registerService(componentOwnerService);
        registryService.registerService(productService);
        registryService.registerService(poolService);
        registryService.registerService(distributionService);

        accessManager.grantRole(PRODUCT_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);
        accessManager.grantRole(POOL_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);
        accessManager.grantRole(DISTRIBUTION_REGISTRAR_ROLE().toInt(), address(componentOwnerService), 0);
    }

    function test_callByAddressWithProductRegistrarRole() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.prank(address(componentOwnerService));

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerProduct(product, productOwner);

        _assert_registered_contract(address(product), info, data);
    }

    function test_callByAddressWithoutProductRegistrarRole() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector,
            outsider)); 

        vm.prank(outsider);

        registryService.registerProduct(product, productOwner);
    }

    // применима ли здесь саморегистрация???
    function test_selfRegistration() public
    {
        vm.startPrank(address(componentOwnerService));

        vm.expectRevert();

        registryService.registerProduct(IBaseComponent(outsider), outsider);      

        vm.expectRevert();

        registryService.registerProduct(IBaseComponent(registryOwner), registryOwner);  

        // if componentOwnerService will support IProductComponent interface -> Registry.ContractAlreadyRegistered
        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotProduct.selector));
        registryService.registerProduct(IBaseComponent(address(componentOwnerService)), address(componentOwnerService));   

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotProduct.selector));

        registryService.registerProduct(IBaseComponent(address(registryService)), address(registryService)); 

        SelfOwnedProductMock product = new SelfOwnedProductMock(
            address(registry),
            instanceNftId,
            toBool(randomNumber(1))); //isInterceptor

        vm.expectRevert(abi.encodeWithSelector(RegistryService.SelfRegistration.selector));

        registryService.registerProduct(IBaseComponent(product), address(product)); 
    }

    function test_withEOA() public
    {
        vm.prank(address(componentOwnerService));

        vm.expectRevert();

        registryService.registerProduct(IBaseComponent(EOA), outsider);
    }

    function test_contractWithoutIERC165() public
    {
        vm.prank(address(componentOwnerService));

        vm.expectRevert();

        registryService.registerProduct(IBaseComponent(contractWithoutIERC165), outsider);
    }

    function test_withIERC165() public
    {
        vm.prank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotProduct.selector));

        registryService.registerProduct(IBaseComponent(erc165), outsider);
    }

    function test_withIRegisterable() public
    {
        vm.prank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(RegistryService.NotProduct.selector));

        registryService.registerProduct(IBaseComponent(address(registerableOwnedByRegistryOwner)), registryOwner);
    }

    // the same as test_callByAddressWithProductRegistrarRole
    function test_withIProductComponent() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);


        vm.prank(address(componentOwnerService));

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerProduct(product, productOwner);

        _assert_registered_contract(address(product), info, data);  
    }

    function test_withInvalidType() public 
    {
        ProductMockWithRandomInvalidType product = new ProductMockWithRandomInvalidType(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.UnexpectedRegisterableType.selector,
            PRODUCT(),
            product._invalidType()));

        vm.prank(address(componentOwnerService));

        registryService.registerProduct(product, productOwner);
    }

    function test_withInvalidAddress() public 
    {
        ProductMockWithRandomInvalidAddress product = new ProductMockWithRandomInvalidAddress(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.prank(address(componentOwnerService));

        (
            IRegistry.ObjectInfo memory info,
            bytes memory data 
        ) = registryService.registerProduct(product, productOwner);

        _assert_registered_contract(address(product), info, data);  
    }

    function test_whenExpectedOwnerIsNotInitialOwner() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor, 
            productOwner);
    
        vm.startPrank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            outsider));

        registryService.registerProduct(product, outsider); 

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerProduct(product, registryOwner); 

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(componentOwnerService)));

        registryService.registerProduct(product, address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(registryService)));

        registryService.registerProduct(product, address(registryService));

        vm.stopPrank; 
    }

    function test_withZeroExpectedOwner() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.prank(address(componentOwnerService));    

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(0)));

        registryService.registerProduct(product, address(0));      
    }

    function test_withZeroInitialOwner() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            address(0));

        vm.startPrank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            outsider));

        registryService.registerProduct(product, outsider); 

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            registryOwner));

        registryService.registerProduct(product, registryOwner); 

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(componentOwnerService)));

        registryService.registerProduct(product, address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.NotRegisterableOwner.selector,
            address(registryService)));

        registryService.registerProduct(product, address(registryService));

        vm.stopPrank();
    }

    function test_withZeroExpectedOwnerAndZeroInitialOwner() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            address(0));

        vm.prank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.RegisterableOwnerIsZero.selector));

        registryService.registerProduct(product, address(0));          
    }

    function test_withRegisteredInitialOwner() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            instanceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            address(componentOwnerService));

        vm.prank(address(componentOwnerService));

        vm.expectRevert(abi.encodeWithSelector(
            RegistryService.RegisterableOwnerIsRegistered.selector));

        registryService.registerProduct(product, address(componentOwnerService));   
    }

    /*function test_whenParentIsNotInstance() public
    {
        ProductMock product = new ProductMock(
            address(registry), 
            registryServiceNftId, 
            toBool(randomNumber(1)), //isInterceptor 
            productOwner);

        vm.prank(address(componentOwnerService));

        //vm.expectRevert(abi.encodeWithSelector(
        //    Registry.InvalidTypesCombination.selector,
        //    PRODUCT(),
        //    SERVICE()));

        registryService.registerProduct(product, productOwner);      
    }*/
}