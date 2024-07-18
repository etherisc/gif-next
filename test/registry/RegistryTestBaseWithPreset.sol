// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {console} from "../../lib/forge-std/src/Test.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";
import {ObjectType, PROTOCOL, REGISTRY, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";

import {RegisterableMock} from "../mock/RegisterableMock.sol";


contract RegistryTestBaseWithPreset is RegistryTestBase
{   // TODO _nftIdByType is actually == _nftIds?
    NftId[] _nftIdByType; // keeps 1 nftId of each type

    NftId _chainRegistryNftId; // use on mainnet only
    address _chainRegistryAddress;
    uint64 _chainRegistryChainId;

    NftId _instanceNftId;
    NftId _productNftId;
    NftId _distributionNftId;
    NftId _poolNftId;
    NftId _oracleNftId;
    NftId _distributorNftId;
    NftId _policyNftId;
    NftId _bundleNftId;
    NftId _stakeForProtocolNftId;
    NftId _stakeForInstanceNftId;


    function setUp() public virtual override
    {
        super.setUp();

        _register_all_types();
    }

    function _registerContractType(ObjectType objectType, NftId parentNftId) internal returns (NftId)
    {
        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = parentNftId;
        info.objectType = objectType;
        info.isInterceptor = true;
        //info.objectAddress = _getRandomNotRegisteredAddress();
        info.initialOwner = address(uint160(randomNumber(1, type(uint160).max)));
        info.data = "";

        bytes32 salt = bytes32(randomNumber(type(uint256).max));

        RegisterableMock registerableMock = new RegisterableMock{salt: salt}(
            info.nftId,
            info.parentNftId,
            info.objectType,
            info.isInterceptor,
            info.initialOwner,
            info.data
        );

        info.objectAddress = address(registerableMock);

        return _assert_register(info, false, "");
    }

    function _registerObjectType(ObjectType objectType, NftId parentNftId) internal returns (NftId)
    {
        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = parentNftId;
        info.objectType = objectType;
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(1, type(uint160).max)));

        return _assert_register(info, false, "");
    }

    function _registerChainRegistry() internal returns (NftId)
    {
        assert(block.chainid == 1);

        _chainRegistryChainId = _getRandomNotRegisteredChainId();
        NftId nftId = NftIdLib.toNftId(
            core.chainNft.calculateTokenId(core.registry.REGISTRY_TOKEN_SEQUENCE_ID(), _chainRegistryChainId)
        );
        _chainRegistryAddress = address(uint160(randomNumber(1, type(uint160).max)));// can have duplicate address, never 0

        _assert_registerRegistry(
            nftId,
            _chainRegistryChainId,
            _chainRegistryAddress, 
            false, "");

        return nftId;
    }

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

        // push already registered types
        _nftIdByType.push(protocolNftId);
        _nftIdByType.push(globalRegistryNftId);
        _nftIdByType.push(registryNftId); // same as globalRegistryNftId on mainnet 
        _nftIdByType.push(stakingNftId);
        _nftIdByType.push(registryServiceNftId);

        _startPrank(address(registryServiceMock));

        _instanceNftId = _registerContractType(INSTANCE(), registryNftId);
        _nftIdByType.push(_instanceNftId);

        _productNftId = _registerContractType(PRODUCT(), _instanceNftId);
        _nftIdByType.push(_productNftId);

        _distributionNftId = _registerContractType(DISTRIBUTION(), _instanceNftId);
        _nftIdByType.push(_distributionNftId);

        _poolNftId = _registerContractType(POOL(), _instanceNftId);
        _nftIdByType.push(_poolNftId);

        _oracleNftId = _registerContractType(ORACLE(), _instanceNftId);
        _nftIdByType.push(_oracleNftId);

        _distributorNftId = _registerObjectType(DISTRIBUTOR(), _distributionNftId);
        _nftIdByType.push(_distributorNftId);

        _policyNftId = _registerObjectType(POLICY(), _productNftId);
        _nftIdByType.push(_policyNftId);

        _bundleNftId = _registerObjectType(BUNDLE(), _poolNftId);
        _nftIdByType.push(_bundleNftId);

        _stakeForProtocolNftId = _registerObjectType(STAKE(), protocolNftId);
        _nftIdByType.push(_stakeForProtocolNftId);

        _stakeForInstanceNftId = _registerObjectType(STAKE(), _instanceNftId);
        _nftIdByType.push(_stakeForInstanceNftId);

        _stopPrank();
        _startPrank(gifAdmin);
        
        // when not on mainnet there are only 2 registry objects, both created at deployment time
        // when on mainnet there is only 1 registry object created at deployment, but arbitrary number can be created after
        if(block.chainid == 1) {
            _nftIdByType.push(_registerChainRegistry());
        }

        _stopPrank();
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