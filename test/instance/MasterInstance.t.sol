// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {console} from "../../lib/forge-std/src/Test.sol";

import {IAccessAdmin} from "../../contracts/authorization/IAccessAdmin.sol";
import {IComponentService} from "../../contracts/shared/IComponentService.sol";
import {IInstance} from "../../contracts/instance/IInstance.sol";
import {IInstanceService} from "../../contracts/instance/IInstanceService.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {GifTest} from "../base/GifTest.sol";
import {InstanceAdmin} from "../../contracts/instance/InstanceAdmin.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract MasterTestInstance is GifTest {


    function test_masterInstanceSetup() public {
        // GIVEN setup

        assertTrue(address(masterInstance) != address(0), "masterInstance not set");
    }
}
