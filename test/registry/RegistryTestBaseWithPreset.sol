// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {blockBlocknumber} from "../../contracts/type/Blocknumber.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/type/Version.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/type/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";


contract RegistryTestBaseWithPreset is RegistryTestBase
{
    mapping(ObjectType objectType => NftId nftId) public _nftIdByType;// default parent nft id for each type

    function setUp() public virtual override
    {
        super.setUp();

        _nftIdByType[PROTOCOL()] = protocolNftId;
        _nftIdByType[REGISTRY()] = registryNftId; // collision with globalRegistryNftId...have the same type

        _startPrank(address(registryServiceMock));

        _register_all_types();

        _stopPrank();
    }

    function _registerContractType(ObjectType objectType, ObjectType parentType) internal
    {
        console.log("Registering object of type %s for %s", _typeName[objectType], _typeName[parentType]);
        
        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[parentType];
        info.objectType = objectType;
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        NftId registeredNftId = _assert_register(info, false, "");
        require(_nftIdByType[objectType].toInt() == 0, "Test error: _nftIdByType[objectType] is already set");
        _nftIdByType[objectType] = registeredNftId;
    }

    function _registerObjectType(ObjectType objectType, ObjectType parentType) internal
    {
        console.log("Registering object of type %s for %s", _typeName[objectType], _typeName[parentType]);

        IRegistry.ObjectInfo memory info;

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[parentType];
        info.objectType = objectType;
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        NftId registeredNftId = _assert_register(info, false, "");
        require(_nftIdByType[objectType].toInt() == 0, "Test error: _nftIdByType[objectType] is already set");
        _nftIdByType[objectType] = registeredNftId;
    }

    function _register_all_types() internal
    {
        IRegistry.ObjectInfo memory info;

        _registerContractType(STAKING(), REGISTRY());
        _registerContractType(INSTANCE(), REGISTRY());
        _registerContractType(PRODUCT(), INSTANCE());
        _registerContractType(POOL(), INSTANCE());
        _registerContractType(ORACLE(), INSTANCE());
        _registerContractType(DISTRIBUTION(), INSTANCE());

        _registerObjectType(STAKE(), PROTOCOL());
        //_registerObjectType(STAKE(), INSTANCE());// collision with STAKE() for PROTOOCOL()
        _registerObjectType(DISTRIBUTOR(), DISTRIBUTION());
        _registerObjectType(POLICY(), PRODUCT());
        _registerObjectType(BUNDLE(), POOL());

    }
}