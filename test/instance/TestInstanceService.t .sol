// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {GifTest} from "../base/GifTest.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";

contract TestInstanceService is GifTest {

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_upgradeMasterInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader();
        newMasterInstanceReader.initialize(address(masterInstance));
        
        // WHEN
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));

        // THEN
        assertEq(address(newMasterInstanceReader), instanceService.getMasterInstanceReaderAddress(), "master instance reader not set");
    }

    function test_upgradeMasterInstanceReader_not_master_instance() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader();
        newMasterInstanceReader.initialize(address(instance));
        
        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstanceService.ErrorInstanceServiceInstanceReaderInstanceMismatch.selector));

        // WHEN
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
    }
    
    function test_upgradeMasterInstanceReader_same_reader() public {
        // GIVEN
        vm.startPrank(registryOwner);

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstanceService.ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader.selector));

        // WHEN
        instanceService.upgradeMasterInstanceReader(address(masterInstanceReader));
    }

    function test_upgradeInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader();
        newMasterInstanceReader.initialize(address(masterInstance));
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
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
        InstanceReader newMasterInstanceReader = new InstanceReader();
        newMasterInstanceReader.initialize(address(masterInstance));
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstanceService.ErrorInstanceServiceRequestUnauhorized.selector, 
                address(this)));

        // WHEN
        instanceService.upgradeInstanceReader(instanceNftId);
    }

}
