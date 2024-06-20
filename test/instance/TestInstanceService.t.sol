// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.24;

import {GifTest} from "../base/GifTest.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";

contract TestInstanceService is GifTest {

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_upgradeMasterInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
        
        // WHEN
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));

        // THEN
        assertEq(address(newMasterInstanceReader), instanceService.getMasterInstanceReader(), "master instance reader not set");
    }

    function test_upgradeMasterInstanceReaderNotMasterInstance() public {
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

    function test_upgradeInstanceReaderAuthorized() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
        instanceService.upgradeMasterInstanceReader(address(newMasterInstanceReader));
        vm.stopPrank();
        
        address oldInstanceReaderAddress = address(instance.getInstanceReader());
        
        assertEq(registry.ownerOf(instanceNftId), instanceOwner, "instanceOwner not owner of instance nft id");

        // WHEN
        vm.startPrank(instanceOwner);
        instanceService.upgradeInstanceReader(instanceNftId);
        vm.stopPrank();
        
        // THEN
        assertFalse(oldInstanceReaderAddress == address(instance.getInstanceReader()), "instance reader not upgraded");
    }

    function test_upgradeInstanceReaderNotAuthorized() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = _createNewMasterInstanceReader();
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


    function _createNewMasterInstanceReader() internal returns (InstanceReader) {
        InstanceReader newMIR = new InstanceReader();
        newMIR.initializeWithInstance(address(masterInstance));
        return newMIR;
    }

}
