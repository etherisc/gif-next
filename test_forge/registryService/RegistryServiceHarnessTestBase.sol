// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";

import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {ObjectType, toObjectType} from "../../contracts/types/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {RegistryService} from "../../contracts/registry/RegistryService.sol";
import {RegistryServiceManagerMock} from "../mock/RegistryServiceManagerMock.sol";
import {RegisterableMock} from "../mock/RegisterableMock.sol";
import {RegistryServiceHarness} from "./RegistryServiceHarness.sol";


// Helper functions to test IRegistry.ObjectInfo structs 
function eqObjectInfo(IRegistry.ObjectInfo memory a, IRegistry.ObjectInfo memory b) pure returns (bool isSame) {
    return (
        (a.nftId == b.nftId) &&
        (a.parentNftId == b.parentNftId) &&
        (a.objectType == b.objectType) &&
        (a.objectAddress == b.objectAddress) &&
        (a.initialOwner == b.initialOwner) &&
        (a.data.length == b.data.length) &&
        keccak256(a.data) == keccak256(b.data)
    );
}

function toBool(uint256 uintVal) pure returns (bool boolVal)
{
    assembly {
        boolVal := uintVal
    }
}

contract RegistryServiceHarnessTestBase is Test, FoundryRandom {

    address public registryOwner = makeAddr("registryOwner");
    address public registerableOwner = makeAddr("registerableOwner");
    address public outsider = makeAddr("outsider");

    RegistryServiceManagerMock public registryServiceManager;
    RegistryServiceHarness public registryServiceHarness;
    IRegistry public registry;

    function setUp() public virtual
    {
        vm.prank(registryOwner);
        registryServiceManager = new RegistryServiceManagerMock();

        registryServiceHarness = RegistryServiceHarness(address(registryServiceManager.getRegistryService()));
        registry = registryServiceManager.getRegistry();
    }

    function _assert_getAndVerifyContractInfo(
        RegisterableMock registerable, 
        ObjectType expectedType, 
        address expectedOwner)
        internal
    {
        ( 
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = registerable.getInitialInfo();
        info.objectAddress = address(registerable);
        bool expectRevert = false;

        if(info.objectType != expectedType) {
            vm.expectRevert(abi.encodeWithSelector(
                RegistryService.UnexpectedRegisterableType.selector,
                expectedType,
                info.objectType));
            expectRevert = true;
        } else if(info.initialOwner != expectedOwner) { 
            vm.expectRevert(abi.encodeWithSelector(
                RegistryService.NotRegisterableOwner.selector,
                expectedOwner));
            expectRevert = true;
        } else if(info.initialOwner == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(
                RegistryService.RegisterableOwnerIsZero.selector));
        }else if(registry.isRegistered(info.initialOwner)) { 
            vm.expectRevert(abi.encodeWithSelector(
                RegistryService.RegisterableOwnerIsRegistered.selector));
            expectRevert = true;
        }

        if(expectRevert) {
            registryServiceHarness.getAndVerifyContractInfo(
                registerable,
                expectedType,
                expectedOwner);
        } else {
            ( 
                IRegistry.ObjectInfo memory infoFromRegistryService,
                bytes memory dataFromRegistryService
            ) = registryServiceHarness.getAndVerifyContractInfo(
                registerable,
                expectedType,
                expectedOwner);  

            assertTrue(eqObjectInfo(info, infoFromRegistryService), 
                "Info read from registerable is different from info returned by registry service");
            assertEq(data, dataFromRegistryService, 
                "Data read from registerable is different from data returned by registry service");
        }
    }
}