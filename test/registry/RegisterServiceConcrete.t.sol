// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";

contract RegisterServiceConcreteTest is RegistryTestBase {

    // previously failing cases 
    function test_registeService_specificCase_1() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                toNftId(10017),
                toNftId(353073667),
                toObjectType(35),
                false, // isInterceptor
                address(2072),
                address(162012514),
                ""                
            ),
            VersionLib.toVersionPart(22),
            toObjectType(244)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_2() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                toNftId(10017),
                toNftId(353073667),
                toObjectType(35),
                false, // isInterceptor
                address(0),
                address(2072),
                ""                
            ),
            VersionLib.toVersionPart(98),
            toObjectType(22)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_3() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                toNftId(7505),
                toNftId(11674931516840186165219379815826254658548193973),
                toObjectType(173),
                false, // isInterceptor
                address(7148),
                address(0x00000000000000000000000000000000000000000000000000000000fdd9ec7e),
                ""                
            ),
            VersionLib.toVersionPart(172),
            toObjectType(185)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_4() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                toNftId(12537),
                toNftId(6191),
                toObjectType(100),
                false, // isInterceptor
                address(16382),
                address(0x0000000000000000000000000000000000000000000000000000000000002181),
                ""                
            ),
            VersionLib.toVersionPart(178),
            toObjectType(44)
        );

        _stopPrank();
    }

    function test_registeService_specificCase_5() public
    {
        _startPrank(0x8Ae8b867cAa4B9ee8ee24323D8b809b692507e54);

        _assert_registerService_withChecks(
            IRegistry.ObjectInfo(
                toNftId(3590),
                toNftId(158),
                toObjectType(220),
                false, // isInterceptor
                address(0x0000000000000000000000000000000000001eF1),
                address(0x000000000000000000000000000000000000000000000000000000000000441c),
                ""                
            ),
            VersionLib.toVersionPart(63),
            toObjectType(99)
        );

        _stopPrank();
    }

    // TODO move to release manager tests
    /*function test_register_ServiceWithZeroMajorVersion() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            zeroNftId(), // any nftId
            registryNftId,
            SERVICE(),
            false, // isInterceptor            
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // initialOwner, any address capable to receive nft
            ""
        );

        while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
        {// guarantee objectAddress is fresh
            info.objectAddress = address(uint160(info.objectAddress) + 1);
        }

        _startPrank(address(registryServiceMock));

        for(uint8 majorVersion = 0; majorVersion < GIF_VERSION; majorVersion++)
        {
            info.data = abi.encode("SomeTestName", VersionLib.toVersionPart(majorVersion));
            _assert_register(info, true, abi.encodeWithSelector(IRegistry.InvalidServiceVersion.selector, VersionLib.toVersionPart(majorVersion)));
        }

        _stopPrank();
    }*/
}

contract RegisterServiceWithPresetConcreteTest is RegistryTestBaseWithPreset, RegisterServiceConcreteTest
{
    function setUp() public virtual override(RegistryTestBase, RegistryTestBaseWithPreset)
    {
        RegistryTestBaseWithPreset.setUp();
    }
}


