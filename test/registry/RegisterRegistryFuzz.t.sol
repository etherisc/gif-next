// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectType, ObjectTypeLib, PROTOCOL, REGISTRY, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";
import {RegistryTestBase} from "./RegistryTestBase.sol";
import {RegistryTestBaseWithPreset} from "./RegistryTestBaseWithPreset.sol";


contract RegisterRegistryFuzzTest is RegistryTestBase 
{
    // sender - always random
    // nftId - random
    // chainId - random
    // registryAddress - random
    function testFuzz_registryRegistry_0000(address sender, NftId nftId, uint64 chainId, address registryAddress) public
    {
        registerRegistry_testFunction(
            sender,
            nftId,
            chainId,
            registryAddress
        );
    }
    // sender - always random
    // nftId - random
    // chainId - random
    // registryAddressIdx - set of addresses (actors + registered + initial owners)
    function testFuzz_registerRegistry_0001(address sender, NftId nftId, uint64 chainId, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            sender, 
            nftId, 
            chainId,
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_0010(address sender, NftId nftId, uint256 chainIdIdx, address registryAddress) public
    {
        registerRegistry_testFunction(
            sender, 
            nftId, 
            _getChainIdAtIndex(chainIdIdx), 
            registryAddress
        );
    }

    function testFuzz_registerRegistry_0011(address sender, NftId nftId, uint256 chainIdIdx, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            sender, 
            nftId, 
            _getChainIdAtIndex(chainIdIdx), 
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_0100(address sender, uint256 nftIdIdx, uint64 chainId, address registryAddress) public
    {
        registerRegistry_testFunction(
            sender, 
            _getNftIdAtIndex(nftIdIdx), 
            chainId, 
            registryAddress
        );
    }

    function testFuzz_registerRegistry_0101(address sender, uint256 nftIdIdx, uint64 chainId, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            sender,
            _getNftIdAtIndex(nftIdIdx), 
            chainId, 
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_0110(address sender, uint256 nftIdIdx, uint256 chainIdIdx, address registryAddress) public
    {
        registerRegistry_testFunction(
            sender,
            _getNftIdAtIndex(nftIdIdx), 
            _getChainIdAtIndex(chainIdIdx), 
            registryAddress
        );
    }

    function testFuzz_registerRegistry_0111(address sender, uint256 nftIdIdx, uint256 chainIdIdx, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            sender,
            _getNftIdAtIndex(nftIdIdx), 
            _getChainIdAtIndex(chainIdIdx), 
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_withValidSender_000(NftId nftId, uint64 chainId, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            chainId,
            registryAddress
        );
    }

    function testFuzz_registerRegistry_withValidSender_001(NftId nftId, uint64 chainId, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            chainId,
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_withValidSender_010(NftId nftId, uint256 chainIdIdx, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            _getChainIdAtIndex(chainIdIdx),
            registryAddress
        );
    }

    function testFuzz_registerRegistry_withValidSender_011(NftId nftId, uint256 chainIdIdx, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            _getChainIdAtIndex(chainIdIdx),
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_withValidSender_100(uint256 nftIdIdx, uint64 chainId, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            _getNftIdAtIndex(nftIdIdx),
            chainId,
            registryAddress
        );
    }

    function testFuzz_registerRegistry_withValidSender_101(uint256 nftIdIdx, uint64 chainId, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            _getNftIdAtIndex(nftIdIdx),
            chainId,
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registerRegistry_withValidSender_110(uint256 nftIdIdx, uint256 chainIdIdx, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            _getNftIdAtIndex(nftIdIdx),
            _getChainIdAtIndex(chainIdIdx),
            registryAddress
        );
    }

    function testFuzz_registerRegistry_withValidSender_111(uint256 nftIdIdx, uint256 chainIdIdx, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            _getNftIdAtIndex(nftIdIdx),
            _getChainIdAtIndex(chainIdIdx),
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registryRegistry_withValidSenderAndNftId_00(uint64 chainId, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId)),
            chainId,
            registryAddress
        );
    }

    function testFuzz_registryRegistry_withValidSenderAndNftId_01(uint64 chainId, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId)),
            chainId,
            _getAddressAtIndex(registryAddressIdx)
        );
    }

    function testFuzz_registryRegistry_withValidSenderAndNftId_10(uint256 chainIdIdx, address registryAddress) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), _getChainIdAtIndex(chainIdIdx))),
            _getChainIdAtIndex(chainIdIdx),
            registryAddress
        );
    }

    function testFuzz_registryRegistry_withValidSenderAndNftId_11(uint256 chainIdIdx, uint256 registryAddressIdx) public
    {
        registerRegistry_testFunction(
            gifAdmin,
            NftIdLib.toNftId(core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), _getChainIdAtIndex(chainIdIdx))),
            _getChainIdAtIndex(chainIdIdx),
            _getAddressAtIndex(registryAddressIdx)
        );
    }
}

contract RegisterRegistryFuzzTestL1 is RegisterRegistryFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }
}

contract RegisterRegistryFuzzTestL2 is RegisterRegistryFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}




contract RegisterRegistryWithPresetFuzzTest is RegistryTestBaseWithPreset, RegisterRegistryFuzzTest
{
    function setUp() public virtual override(RegistryTestBase, RegistryTestBaseWithPreset)
    {
        RegistryTestBaseWithPreset.setUp();
    }
}

contract RegisterRegistryWithPresetFuzzTestL1 is RegisterRegistryWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(1);
        super.setUp();
    }

    // !!! TODO check that each itteration has unique chainRegistryChainId -> setUp() is executed for each itteration
    // Mainnet only tests
    function testFuzz_registerRegistry_withDuplicateChainId(address registryAddress) public
    {
        vm.assume(block.chainid == 1);
        vm.assume(registryAddress != address(0));
        assert(_chainRegistryChainId != 0);
        //vm.assume(!EnumerableSet.contains(_registeredAddresses, registryAddress)); // chain registries can have same addresses

        // duplicate registration with random chain id from setUp()
        NftId nftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), _chainRegistryChainId)
        );

        // must revert with abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryAlreadyRegistered.selector, nftId, _chainRegistryChainId)
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            _chainRegistryChainId,
            registryAddress
        );

        // duplicate registration with mainnet chain id
        nftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), 1)
        );

        // must revert with abi.encodeWithSelector(IRegistry.ErrorRegistryChainRegistryAlreadyRegistered.selector, nftId, 1)
        registerRegistry_testFunction(
            gifAdmin,
            nftId,
            1,
            registryAddress
        );
    }
}

contract RegisterRegistryWithPresetFuzzTestL2 is RegisterRegistryWithPresetFuzzTest
{
    function setUp() public virtual override {
        vm.chainId(_getRandomChainId());
        super.setUp();
    }
}