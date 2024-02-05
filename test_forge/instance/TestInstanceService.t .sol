// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../../lib/forge-std/src/Script.sol";
import {TestGifBase} from "../base/TestGifBase.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";

contract TestInstanceService is TestGifBase {

    uint256 public constant INITIAL_BALANCE = 100000;

    function test_setMasterInstanceReader() public {
        // GIVEN
        vm.startPrank(registryOwner);
        InstanceReader newMasterInstanceReader = new InstanceReader(address(registry), masterInstanceNftId);
        
        // WHEN
        instanceService.setMasterInstanceReader(address(newMasterInstanceReader));

        // THEN
        assertEq(address(newMasterInstanceReader), instanceService.getInstanceReaderMaster(), "master instance reader not set");
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

}
