// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";
import {ObjectType, PROTOCOL, REGISTRY, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";


contract RegistryTestBaseWithPreset is RegistryTestBase
{
    NftId[] _nftIdByType; // keeps 1 nftId of each type

    NftId chainRegistryNftId; // used on mainnet only
    NftId instanceNftId;
    NftId productNftId;
    NftId distributionNftId;
    NftId poolNftId;
    NftId oracleNftId;
    NftId distributorNftId;
    NftId policyNftId;
    NftId bundleNftId;
    NftId stakeForProtocolNftId;
    NftId stakeForInstanceNftId;


    function setUp() public virtual override
    {
        super.setUp();
        // TODO _nftIdByType is actually == _nftIds?
        _nftIdByType.push(protocolNftId);
        _nftIdByType.push(globalRegistryNftId);
        _nftIdByType.push(registryNftId); // same as globalRegistryNftId on mainnet 
        _nftIdByType.push(stakingNftId);
        _nftIdByType.push(registryServiceNftId);

        _startPrank(address(registryServiceMock));

        _register_all_types();

        _stopPrank();

        _startPrank(gifAdmin);
        
        // when not on mainnet there are only 2 registry objects, both created at deployment time
        // when on mainnet there is only 1 registry object created at deployment, but arbitrary number can be created after...
        if(block.chainid == 1) {
            _registerChainRegistry();
        }

        _stopPrank();
    }

    function _registerContractType(ObjectType objectType, NftId parentNftId) internal returns (NftId)
    {
        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = parentNftId;
        info.objectType = objectType;
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        return _assert_register(info, false, "");
    }

    function _registerObjectType(ObjectType objectType, NftId parentNftId) internal returns (NftId)
    {
        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = parentNftId;
        info.objectType = objectType;
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        return _assert_register(info, false, "");
    }

    function _registerChainRegistry() internal returns (NftId)
    {
        uint64 chainId;
        
        do{
            chainId = uint64(randomNumber(type(uint64).max));
        } while(chainId == 0 || chainId == 1);
        
        NftId nftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), chainId)
        );

        _assert_registerRegistry(
            nftId,
            chainId,
            address(uint160(randomNumber(11, type(uint160).max))), 
            false, "");

        return nftId;
    }

    // TODO register service AND registry (if mainnet)
    function _register_all_types() internal
    {
        IRegistry.ObjectInfo memory info;
        // TODO register each type while looping thorugh _types set
        /*  
        for (uint256 i = 0; i < _validCoreContractTypesCombos.length(); i++)
        {
            ObjectTypePair contractTypePair = EnumerableSet.at(_validCoreContractTypesCombos, i);
            _registerContractType(contractTypePair);
        }

        for (uint256 i = 0; i < _validCoreObjectTypesCombos.length(); i++) 
        {
            ObjectTypePair objectTypePair = EnumerableSet.at(_validCoreObjectTypesCombos, i);
            _registerObjectType(objectTypePair);
        }
        */

        instanceNftId = _registerContractType(INSTANCE(), registryNftId);
        _nftIdByType.push(instanceNftId);

        productNftId = _registerContractType(PRODUCT(), instanceNftId);
        _nftIdByType.push(productNftId);

        distributionNftId = _registerContractType(DISTRIBUTION(), instanceNftId);
        _nftIdByType.push(distributionNftId);

        poolNftId = _registerContractType(POOL(), instanceNftId);
        _nftIdByType.push(poolNftId);

        oracleNftId = _registerContractType(ORACLE(), instanceNftId);
        _nftIdByType.push(oracleNftId);

        distributorNftId = _registerObjectType(DISTRIBUTOR(), distributionNftId);
        _nftIdByType.push(distributorNftId);

        policyNftId = _registerObjectType(POLICY(), productNftId);
        _nftIdByType.push(policyNftId);

        bundleNftId = _registerObjectType(BUNDLE(), poolNftId);
        _nftIdByType.push(bundleNftId);

        stakeForProtocolNftId = _registerObjectType(STAKE(), protocolNftId);
        _nftIdByType.push(stakeForProtocolNftId);

        stakeForInstanceNftId = _registerObjectType(STAKE(), instanceNftId);
        _nftIdByType.push(stakeForInstanceNftId);
    }
/*
    function prepapreTestForChainId(uint64 chainId) internal virtual override returns (RegistryTestBase test) {
        vm.assume(chainId > 0);

        // forge: chain ID must be less than 2^64 - 1
        vm.chainId(chainId);

        test = new RegistryTestBaseWithPreset();
        test.setUp();
    }
*/
}