// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../base/TestGifBase.sol";
import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {PRODUCT_OWNER_ROLE, RoleIdLib} from "../../contracts/types/RoleId.sol";
import {MockProduct, SPECIAL_ROLE_INT} from "../mock/MockProduct.sol";
import {FeeLib} from "../../contracts/types/Fee.sol";

contract TestInstanceService is TestGifBase {

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_setMasterInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader(address(registry), masterInstanceNftId);
        
        // WHEN
        instanceService.setMasterInstanceReader(address(newMasterInstanceReader));

        // THEN
        assertEq(address(newMasterInstanceReader), instanceService.getMasterInstanceReader(), "master instance reader not set");
    }

    function test_setMasterInstanceReader_not_master_instance() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader(address(registry), instanceNftId);
        
        // THEN
        vm.expectRevert("ERROR:CRD-015:INSTANCE_READER_INSTANCE_MISMATCH");

        // WHEN
        instanceService.setMasterInstanceReader(address(newMasterInstanceReader));
    }
    
    function test_setMasterInstanceReader_same_reader() public {
        // GIVEN
        vm.startPrank(registryOwner);

        // THEN
        vm.expectRevert("ERROR:CRD-014:INSTANCE_READER_MASTER_SAME_AS_NEW");

        // WHEN
        instanceService.setMasterInstanceReader(address(masterInstanceReader));
    }

    function test_upgradeInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader(address(registry), masterInstanceNftId);
        instanceService.setMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        address oldInstanceReaderAddress = address(instance.getInstanceReader());
        vm.startPrank(instanceOwner);
        
        // WHEN
        instanceService.upgradeInstanceReader(instanceNftId);
        
        // THEN
        assertFalse(oldInstanceReaderAddress == address(instance.getInstanceReader()), "instance reader not upgraded");
    }

    function test_upgradeInstanceReader_not_authorized() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader(address(registry), masterInstanceNftId);
        instanceService.setMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        // THEN
        vm.expectRevert(abi.encodeWithSelector(IInstanceService.ErrorInstanceServiceRequestUnauhorized.selector, address(this)));

        // WHEN
        instanceService.upgradeInstanceReader(instanceNftId);
    }

    function test_InstanceService_hasRole_unauthorized() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new MockProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );
        vm.stopPrank();

        vm.startPrank(outsider);

        // THEN - missing role
        vm.expectRevert(abi.encodeWithSelector(IBaseComponent.ErrorBaseComponentUnauthorized.selector, outsider, 11111));

        // WHEN
        MockProduct dproduct = MockProduct(address(product));
        dproduct.doSomethingSpecial();

    }

    function test_InstanceService_hasRole_customRole() public {
        // GIVEN
        vm.startPrank(instanceOwner);
        instanceAccessManager.grantRole(PRODUCT_OWNER_ROLE(), productOwner);
        instanceService.createRole(RoleIdLib.toRoleId(SPECIAL_ROLE_INT), "SpecialRole", instanceNftId);
        instanceService.grantRole(RoleIdLib.toRoleId(SPECIAL_ROLE_INT), outsider, instanceNftId);
        vm.stopPrank();

        _prepareDistributionAndPool();

        vm.startPrank(productOwner);
        product = new MockProduct(
            address(registry),
            instanceNftId,
            address(token),
            false,
            address(pool), 
            address(distribution),
            FeeLib.zeroFee(),
            FeeLib.zeroFee(),
            productOwner
        );
        vm.stopPrank();

        vm.startPrank(outsider);

        // WHEN
        MockProduct dproduct = MockProduct(address(product));
        dproduct.doSomethingSpecial();

        // THEN above call was authorized
    }
}
