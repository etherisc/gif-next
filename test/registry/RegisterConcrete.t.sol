// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";

contract RegisterConcreteTest is RegistryTestBase {

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
                NftIdLib.toNftId(EnumerableSet.at(_nftIds, 2620112370 % EnumerableSet.length(_nftIds))),
                _types[199 % _types.length],
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
                NftIdLib.toNftId(EnumerableSet.at(_nftIds, 1794 % EnumerableSet.length(_nftIds))),
                _types[167 % _types.length],
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

        _register_testFunction(sender, info);

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

        bytes memory reason_NotRegistryService = abi.encodeWithSelector(IRegistry.ErrorRegistryCallerNotRegistryService.selector);

        // outsider can not register
        _startPrank(outsider);
        _assert_register(info, true, reason_NotRegistryService);
        _stopPrank();

        _startPrank(registryOwner);
        // registryOwner can not register
        _assert_register(info, true, reason_NotRegistryService);

        // transfer to outsider
        chainNft.approve(outsider, registryServiceNftId.toInt());
        chainNft.safeTransferFrom(registryOwner, outsider, registryServiceNftId.toInt(), "");

        // registryOwner is not owner anymore, still can not register
        _assert_register(info, true, reason_NotRegistryService);

        _stopPrank();

        // registryService, still can register
        _startPrank(address(registryServiceMock));
        _assert_register(info, false, "");
        _stopPrank();

        // outsider is new owner, still can not register
        _startPrank(outsider);
        _assert_register(info, true, reason_NotRegistryService);
        _stopPrank();
    }
}


