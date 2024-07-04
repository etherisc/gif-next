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


import {RegisterFuzzTest} from "./RegisterFuzz.t.sol";

contract RegisterConcreteTest is RegistryTestBase {

    // adding new case from fuzzing
    // 1). create function test_register_specificCase_<N>
    // 2). copy failing test function arguments and signature in the new test function
    // 3). create and setUp() test contract
    // 3). run failing function from test contract with copied arguments

    // previously failing cases 
    function test_register_specificCases() public
    {
        _startPrank(0xb6F322D9421ae42BBbB5CC277CE23Dbb08b3aC1f);

        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(16158753772191290777002328881),
                NftIdLib.toNftId(193),
                ObjectTypeLib.toObjectType(160),
                false, // isInterceptor
                0x9c538400FeC769e651E6552221C88A29660f0DE5,
                0x643A203932303038363435323830353333323539,
                ""                
            ));

        _stopPrank();
        _startPrank(address(registryServiceMock));

        // parentNftId == _chainNft.mint() && objectAddress == initialOwner
        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(3471),
                NftIdLib.toNftId(43133705),
                ObjectTypeLib.toObjectType(128),
                false, // isInterceptor
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                ""              
            ));

        // precompile address as owner
        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(76658180398758015949026343204),
                NftIdLib.toNftId(17762988911415987093326017078),
                ObjectTypeLib.toObjectType(21),
                false, // isInterceptor
                0x85Cf4Fe71daF5271f8a5C1D4E6BB4bc91f792e27,
                0x0000000000000000000000000000000000000008,
                ""            
            ));

        // initialOwner is cheat codes contract address
        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(15842010466351085404296329522),
                NftIdLib.toNftId(16017),
                ObjectTypeLib.toObjectType(19),
                false, // isInterceptor
                0x0C168C3a4589B65fFf12444A0c88125a416927DD,
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            ));

        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(0),
                NftIdLib.toNftId(162),
                ObjectTypeLib.toObjectType(0),
                false, // isInterceptor
                0x733A203078373333613230333037383337333333,
                0x4e59b44847b379578588920cA78FbF26c0B4956C,
                ""        
            ));

        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(133133705),
                registryNftId,
                SERVICE(),
                false, // isInterceptor
                0x0000000000000000000000000000000000000001,
                0x6AB133Ce3481A06313b4e0B1bb810BCD670853a4,
                ""
            ));

        _stopPrank();
        _startPrank(0x0000000000000000000000000000000042966C69);

        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(22045),
                _getNftIdAtIndex(2620112370),
                _getObjectTypeAtIndex(199),
                false, // isInterceptor
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            ));

        _stopPrank();
        _startPrank(0x000000000000000000000000000000000000185e);

        _assert_register_withChecks(
            IRegistry.ObjectInfo(
                NftIdLib.toNftId(5764),
                _getNftIdAtIndex(1794),
                _getObjectTypeAtIndex(167),
                false,
                address(0),
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D,
                ""        
            ));

        _stopPrank();
        
    }

    function test_register_specificCase_2() public
    {
        //args=[0x0000000000000000000000000000000000000000, 0, 3, 45, false, 0x0000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000001, 0x]] 
        //testFuzz_register_0010000(address,uint96,uint256,uint8,bool,address,address,bytes)

        address sender = address(0x0000000000000000000000000000000000000000);

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(0),
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, 3 % EnumerableSet.length(_nftIds))),
            ObjectTypeLib.toObjectType(45),
            false,
            address(0x0000000000000000000000000000000000000001),
            address(0x0000000000000000000000000000000000000001),
            "0x000000000000000000000000000000000000000000000000000000000000285d"
        );

        register_testFunction(sender, info);

    }

    function test_register_specificCase_3() public
    {
        // args=[0xa2D05a7E8Cce6BEBd53E90986223003EC13A9fd5, 37981013685 [3.798e10], 115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77], 13, true, 0x749fE300556DDb33334E1CBD1a0070aB933A2d96, 0xf9472e2c1691cd0f268bbc652cb91347ecd7917dc8a988ac15c2d9f4dbb203f9eacbbc0f3035c78e7e]
        // testFuzz_register_withZeroObjectAddress_00110(address,uint96,uint256,uint8,bool,address,bytes)
        // testFuzz_register_withZeroObjectAddress_00110(address sender, NftId nftId, uint parentIdx, uint8 objectTypeIdx, bool isInterceptor, address initialOwner, bytes memory data)
        
        RegisterFuzzTest test = new RegisterFuzzTest();
        test.setUp();

        test.testFuzz_register_withZeroObjectAddress_00110(
            address(0xa2D05a7E8Cce6BEBd53E90986223003EC13A9fd5),
            NftIdLib.toNftId(37981013685),
            115792089237316195423570985008687907853269984665640564039457584007913129639933,
            13,
            true,
            address(0x749fE300556DDb33334E1CBD1a0070aB933A2d96),
            "0xf9472e2c1691cd0f268bbc652cb91347ecd7917dc8a988ac15c2d9f4dbb203f9eacbbc0f3035c78e7e"
        );
        /*
        address sender = address(0xa2D05a7E8Cce6BEBd53E90986223003EC13A9fd5);

        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(37981013685),
            NftIdLib.toNftId(EnumerableSet.at(_nftIds, 115792089237316195423570985008687907853269984665640564039457584007913129639933 % EnumerableSet.length(_nftIds))),
            _types[13 % _types.length],
            true,
            address(0x0000000000000000000000000000000000000000),
            address(0x749fE300556DDb33334E1CBD1a0070aB933A2d96),
            "0xf9472e2c1691cd0f268bbc652cb91347ecd7917dc8a988ac15c2d9f4dbb203f9eacbbc0f3035c78e7e"
        );

        register_testFunction(sender, info);
        */
    }

    function test_registerWithGlobalRegistryAsParent() public
    {
        // register for global registry
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.toNftId(0),
            registry.GLOBAL_REGISTRY_NFT_ID(),
            INSTANCE(), // or SERVICE
            false,
            address(uint160(randomNumber(type(uint160).max))),
            registryOwner,
            ""
        );

        _startPrank(address(registryServiceMock));
        _assert_register(
            info, 
            true, 
            abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, info.objectType, info.parentNftId));
        _stopPrank();
    }

    // TODO move to RegistryService.t.sol
    function test_registryOwnerNftTransfer() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.zero(), // any nftId
            registryNftId,
            INSTANCE(),
            false,
            address(uint160(randomNumber(type(uint160).max))),
            outsider, // any address capable to receive nft
            ""
        );

        while(EnumerableSet.contains(_registeredAddresses, info.objectAddress)) 
        {// guarantee objectAddress is fresh
            info.objectAddress = address(uint160(info.objectAddress) + 1);
        }

        // outsider can not register
        _startPrank(outsider);
        _assert_register(
            info, 
            true, 
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender));
        _stopPrank();

        _startPrank(registryOwner);
        // registryOwner can not register
        _assert_register(
            info, 
            true, 
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender));

        // transfer to outsider
        chainNft.approve(outsider, registryServiceNftId.toInt());
        chainNft.safeTransferFrom(registryOwner, outsider, registryServiceNftId.toInt(), "");

        // registryOwner is not owner anymore, still can not register
        _assert_register(
            info, 
            true, 
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender));

        _stopPrank();

        // registryService, still can register
        _startPrank(address(registryServiceMock));
        _assert_register(info, false, "");
        _stopPrank();

        // outsider is new owner, still can not register
        _startPrank(outsider);
        _assert_register(
            info, 
            true,
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, _sender));
        _stopPrank();
    }
}


