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

        _nftIdByType.push(protocolNftId);
        _nftIdByType.push(globalRegistryNftId);
        _nftIdByType.push(registryNftId); // have same type as globalRegistryNftId 
        _nftIdByType.push(stakingNftId);
        _nftIdByType.push(registryServiceNftId);

        _startPrank(address(registryServiceMock));

        _register_all_types();

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
}