// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {blockTimestamp} from "../../contracts/types/Timestamp.sol";
import {blockBlocknumber} from "../../contracts/types/Blocknumber.sol";
import {VersionLib, Version, VersionPart} from "../../contracts/types/Version.sol";
import {NftId, toNftId, zeroNftId} from "../../contracts/types/NftId.sol";
import {Timestamp, TimestampLib} from "../../contracts/types/Timestamp.sol";
import {Blocknumber, BlocknumberLib} from "../../contracts/types/Blocknumber.sol";
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, BUNDLE, POLICY, STAKE} from "../../contracts/types/ObjectType.sol";

import {ChainNft} from "../../contracts/registry/ChainNft.sol";
import {IChainNft} from "../../contracts/registry/IChainNft.sol";

import {IRegistry} from "../../contracts/registry/IRegistry.sol";
import {Registry} from "../../contracts/registry/Registry.sol";

import {RegistryTestBase} from "./RegistryTestBase.sol";


contract RegistryTestBaseWithPreset is RegistryTestBase
{
    mapping(ObjectType objectType => NftId nftId) public _nftIdByType;// default parent nft id for each type

    function setUp() public virtual override
    {
        super.setUp();

        _nftIdByType[zeroObjectType()] = zeroNftId(); 
        _nftIdByType[PROTOCOL()] = protocolNftId;
        _nftIdByType[REGISTRY()] = registryNftId; // collision with globalRegistryNftId...have the same type
        _nftIdByType[SERVICE()] = registryServiceNftId; 

        _startPrank(address(registryService));

        _register_all_types();

        _stopPrank();
    }

    function _register_all_types() internal
    {
        IRegistry.ObjectInfo memory info;

        // solhint-disable no-console
        console.log("Registering token");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[REGISTRY()];
        info.objectType = TOKEN();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[TOKEN()] = info.nftId;

        console.log("Token nftId:", _nftIdByType[TOKEN()].toInt());
        console.log("Registering instance");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[REGISTRY()];
        info.objectType = INSTANCE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[INSTANCE()] = info.nftId;

        console.log("Instance nftId: %s", _nftIdByType[INSTANCE()].toInt());
        console.log("Registering product");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = PRODUCT();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[PRODUCT()] = info.nftId;

        console.log("Product nftId: %s", _nftIdByType[PRODUCT()].toInt());
        console.log("Registering pool");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = POOL();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[POOL()] = info.nftId;

        console.log("Pool nftId: %s", _nftIdByType[POOL()].toInt());
        console.log("Registering oracle");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = ORACLE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[ORACLE()] = info.nftId;

        console.log("Oracle nftId: %s", _nftIdByType[ORACLE()].toInt());
        console.log("Registering distribution");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = DISTRIBUTION();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[DISTRIBUTION()] = info.nftId;

        console.log("Distribution nftId: %s", _nftIdByType[DISTRIBUTION()].toInt());
        console.log("Registering policy");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[PRODUCT()];
        info.objectType = POLICY();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[POLICY()] = info.nftId;   

        console.log("Policy nftId: %s", _nftIdByType[POLICY()].toInt());
        console.log("Registering bundle");   

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = BUNDLE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[BUNDLE()] = info.nftId; 

        console.log("Bundle nftId: %s", _nftIdByType[BUNDLE()].toInt());
        console.log("Registering stake");

        info.nftId = toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = STAKE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        info.nftId = registry.register(info);
        _afterRegistration_setUp(info);
        _nftIdByType[STAKE()] = info.nftId;

        console.log("Stake nftId: %s\n", _nftIdByType[STAKE()].toInt());
        // solhint-enable
    }
}