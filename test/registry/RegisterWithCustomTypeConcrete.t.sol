// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";
import {RegisterWithCustomTypeFuzzTest} from "./RegisterWithCustomTypeFuzz.t.sol";

contract RegisterWithCustomTypeConcreteTest is RegistryTestBase {

    // adding new case from fuzzing
    // 1). create function test_registerWithCustomType_specificCase_<N>
    // 2). copy failing test function arguments and signature in the new test function
    // 3). create and setUp() test contract
    // 3). run failing function from test contract with copied arguments

    // previously failing cases

}

contract RegisterWithCustomTypeConcreteTestL1 is RegisterWithCustomTypeConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterWithCustomTypeConcreteTestL2 is RegisterWithCustomTypeConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}

// TODO fix/re-activate
// contract RegisterWithCustomTypeWithPresetConcreteTest is RegistryTestBaseWithPreset
// {
//     function test_registerWithCustomType_withObjectTypeParent() public
//     {
//         ObjectType customObjectType = ObjectTypeLib.toObjectType(randomNumber(type(uint8).max));

//         while(EnumerableSet.contains(_types, customObjectType.toInt())) {
//             customObjectType = ObjectTypeLib.toObjectType(customObjectType.toInt() + 1);
//         }

//         IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
//             NftIdLib.toNftId(0),
//             _policyNftId, // or bundleNftId, stakeNftId, distrbutorNftId
//             customObjectType,
//             false,
//             address(uint160(randomNumber(type(uint160).max))),
//             registryOwner,
//             ""
//         );

//         _startPrank(address(registryServiceMock));
//         _assert_registerWithCustomType(info, false, "");
//         _stopPrank();
//     }

// }

// contract RegisterWithCustomTypeWithPresetConcreteTestL1 is RegisterWithCustomTypeWithPresetConcreteTest
// {
//     function setUp() public virtual override {
//         vm.chainId(1);
//         super.setUp();
//     }
// }

// contract RegisterWithCustomTypeWithPresetConcreteTestL2 is RegisterWithCustomTypeWithPresetConcreteTest
// {
//     function setUp() public virtual override {
//         vm.chainId(_getRandomChainId());
//         super.setUp();
//     }
// }
