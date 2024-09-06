// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";

import {GifTest} from "../base/GifTest.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";

contract InstanceReaderTest is GifTest {

    function test_instanceReaderSetUp() public {
        // GIVEN just set up
        // THEN
        assertEq(address(instanceReader.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(instanceReader.getInstance()), address(instance), "unexpected instance address");
        assertEq(instanceReader.getInstanceNftId().toInt(), instanceNftId.toInt(), "unexpected instance nft id");
    }


    function test_instanceReaderUpgradeMasterInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
        // address newMasterInstanceReaderAddress = address(newMasterInstanceReader);
        
        vm.expectEmit();
        emit IInstanceService.LogInstanceServiceMasterInstanceReaderUpgraded(masterInstanceNftId, address(newMasterInstanceReader));

        // WHEN
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));

        // THEN
        assertEq(
            address(newMasterInstanceReader), 
            instanceService.getMasterInstanceReader(), "master instance reader not set");
    }

    function test_instanceReaderUpgradeMasterInstanceReaderNotMasterInstance() public {
        // GIVEN
        InstanceReader newMasterInstanceReader = new InstanceReader();        

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstanceService.ErrorInstanceServiceInstanceReaderInstanceMismatch.selector));

        // WHEN
        vm.startPrank(registryOwner);
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
    }
    
    function test_instanceReaderUpgradeMasterInstanceReader_same_reader() public {
        // GIVEN
        vm.startPrank(registryOwner);

        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                IInstanceService.ErrorInstanceServiceInstanceReaderSameAsMasterInstanceReader.selector));

        // WHEN
        instanceService.upgradeMasterInstanceReader(address(masterInstanceReader));
    }

    function test_instanceReaderUpgradeInstanceReaderAuthorized() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        address oldInstanceReaderAddress = address(instance.getInstanceReader());
        
        assertEq(registry.ownerOf(instanceNftId), instanceOwner, "instanceOwner not owner of instance nft id");

        // WHEN
        vm.startPrank(instanceOwner);

        vm.expectEmit(true, false, false, false);
        emit IInstanceService.LogInstanceServiceInstanceReaderUpgraded(instanceNftId, address(newMasterInstanceReader));

        instance.upgradeInstanceReader();
        vm.stopPrank();
        
        // THEN
        assertFalse(oldInstanceReaderAddress == address(instance.getInstanceReader()), "instance reader not upgraded");
    }

    function test_instanceReaderUpgradeInstanceReaderNotAuthorized() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        // THEN
        vm.expectRevert(
            abi.encodeWithSelector(
                INftOwnable.ErrorNftOwnableNotOwner.selector, 
                poolOwner));

        // WHEN
        vm.prank(poolOwner);
        instance.upgradeInstanceReader();
    }


    function _createNewMasterInstanceReader() internal returns (InstanceReader) {
        InstanceReader newMIR = new InstanceReader();
        newMIR.initializeWithInstance(address(masterInstance));
        return newMIR;
    }

}
