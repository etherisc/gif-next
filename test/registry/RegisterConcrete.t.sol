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

    function test_register_withGlobalRegistryAsParent() public
    {
        IRegistry.ObjectInfo memory info = IRegistry.ObjectInfo(
            NftIdLib.zero(),
            globalRegistryNftId,
            INSTANCE(), // or SERVICE
            false, // isInterceptor
            _getRandomNotRegisteredAddress(),
            registryOwner,
            ""
        );

        _startPrank(address(registryServiceMock));

        if(block.chainid == 1) {
            _assert_register(info, false, "");
        } else {
            _assert_register(
                info, 
                true, 
                abi.encodeWithSelector(IRegistry.ErrorRegistryGlobalRegistryAsParent.selector, info.objectAddress, info.objectType));
        }

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
        core.chainNft.approve(outsider, registryServiceNftId.toInt());
        core.chainNft.safeTransferFrom(registryOwner, outsider, registryServiceNftId.toInt(), "");

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

contract RegisterConcreteTestL1 is RegisterConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterConcreteTestL2 is RegisterConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}


contract RegisterWithPresetConcreteTest is RegistryTestBaseWithPreset, RegisterConcreteTest
{
    function setUp() public virtual override(RegistryTestBaseWithPreset, RegistryTestBase)
    {
        RegistryTestBaseWithPreset.setUp();
    }

   function test_register_withRegisteredChainRegistryAddress() 
        public
    {
        _startPrank(address(registryServiceMock));

        if(block.chainid == 1) {
            assert(_chainRegistryAddress != address(0));

            // register product with registered chain registry address
            IRegistry.ObjectInfo memory info_1 = IRegistry.ObjectInfo(
                NftIdLib.zero(),
                _instanceNftId,
                PRODUCT(),
                false, // isInterceptor
                _chainRegistryAddress,
                address(uint160(randomNumber(1, type(uint160).max))),
                ""
            );

            _assert_register(info_1, false, "");

            // register instance with global registry address (address lookup set)
            IRegistry.ObjectInfo memory info_2 = IRegistry.ObjectInfo(
                NftIdLib.zero(),
                globalRegistryNftId,
                INSTANCE(),
                false, // isInterceptor
                globalRegistryInfo.objectAddress,
                address(uint160(randomNumber(1, type(uint160).max))),
                ""
            );

            _assert_register(
                info_2, true, 
                abi.encodeWithSelector(
                    IRegistry.ErrorRegistryContractAlreadyRegistered.selector,
                    info_2.objectAddress
                )
            );
        }
        else 
        {
            // register instance with global registry address (address lookup not set)
            IRegistry.ObjectInfo memory info_1 = IRegistry.ObjectInfo(
                NftIdLib.zero(),
                registryNftId,
                INSTANCE(),
                false, // isInterceptor
                globalRegistryInfo.objectAddress,
                address(uint160(randomNumber(1, type(uint160).max))),
                ""
            );

            _assert_register(info_1, false, "");

            // register pool with registry address 
            IRegistry.ObjectInfo memory info_2 = IRegistry.ObjectInfo(
                NftIdLib.zero(),
                _instanceNftId,
                POOL(),
                false, // isInterceptor
                address(core.registry),
                address(uint160(randomNumber(1, type(uint160).max))),
                ""
            );

            _assert_register(
                info_2, true, 
                abi.encodeWithSelector(
                    IRegistry.ErrorRegistryContractAlreadyRegistered.selector,
                    info_2.objectAddress
                )
            );
        }

        _stopPrank();
    }
}

contract RegisterWithPresetConcreteTestL1 is RegisterWithPresetConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterWithPresetConcreteTestL2 is RegisterWithPresetConcreteTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}
