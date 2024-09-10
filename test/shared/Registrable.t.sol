// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {IRegistryLinked} from "../../contracts/shared/IRegistryLinked.sol";
import {INftOwnable} from "../../contracts/shared/INftOwnable.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {VersionPart, VersionPartLib } from "../../contracts/type/Version.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManager} from "../../contracts/registry/RegistryServiceManager.sol";
import {RegistryAdmin} from "../../contracts/registry/RegistryAdmin.sol";
import {Dip} from "../../contracts/mock/Dip.sol";
import {NftOwnableMock, NftOwnableMockUninitialized} from "../mock/NftOwnableMock.sol";

import {GifTest} from "../base/GifTest.sol";

contract RegistrableTest is GifTest {

    function testOnlyActive() public {
        (
            product, 
            productNftId
        ) = _deployAndRegisterNewSimpleProduct("testOnlyActive");

        vm.startPrank(productOwner);
        product.doSomethingOnlyWhenActive();
        vm.stopPrank();

        // WHEN - locked
        vm.startPrank(instanceOwner);
        instance.setTargetLocked(address(product), true);
        vm.stopPrank();

        // THEN - call reverts
        vm.startPrank(productOwner);
        vm.expectRevert(abi.encodeWithSelector(IRegisterable.ErrorRegisterableNotActive.selector));
        product.doSomethingOnlyWhenActive();
        vm.stopPrank();


        // WHEN - unlocked
        vm.startPrank(instanceOwner);
        instance.setTargetLocked(address(product), false);
        vm.stopPrank();

        // THEN - call is succcessful
        vm.startPrank(productOwner);
        product.doSomethingOnlyWhenActive();
    }

}