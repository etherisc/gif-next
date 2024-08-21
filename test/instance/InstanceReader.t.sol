// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract TestInstance is GifTest {

    function setUp() public override {
        super.setUp();
    }
    
    function test_instanceReader() public {
        // GIVEN just set up
        // THEN
        assertEq(address(instanceReader.getRegistry()), address(registry), "unexpected registry address");
        assertEq(address(instanceReader.getInstance()), address(instance), "unexpected instance address");
        assertEq(instanceReader.getInstanceNftId().toInt(), instanceNftId.toInt(), "unexpected instance nft id");
    }
}
