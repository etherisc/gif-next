// SPDX-License-Identifier: UNLICENSED
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
import {ObjectType, ObjectTypeLib, toObjectType, zeroObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, PRODUCT, POOL, ORACLE, DISTRIBUTION, DISTRIBUTOR, BUNDLE, POLICY, STAKE} from "../../contracts/type/ObjectType.sol";

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

        _nftIdByType[zeroObjectType()] = NftIdLib.zero(); 
        _nftIdByType[PROTOCOL()] = protocolNftId;
        _nftIdByType[REGISTRY()] = registryNftId; // collision with globalRegistryNftId...have the same type

        _startPrank(address(registryServiceMock));

        _register_all_types();

        _stopPrank();
    }

    function _register_all_types() internal
    {
        IRegistry.ObjectInfo memory info;

        console.log("Registering instance");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[REGISTRY()];
        info.objectType = INSTANCE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[INSTANCE] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering product");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = PRODUCT();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[PRODUCT] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering pool");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = POOL();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[POOL] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering oracle");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = ORACLE();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[ORACLE] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering distribution");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[INSTANCE()];
        info.objectType = DISTRIBUTION();
        info.objectAddress = address(uint160(randomNumber(11, type(uint160).max)));
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[DISTRIBUTION] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering distributor");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[DISTRIBUTION()];
        info.objectType = DISTRIBUTOR();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[DISTRIBUTOR] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering policy");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[PRODUCT()];
        info.objectType = POLICY();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[POLICY] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering bundle");   

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = BUNDLE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[BUNDLE] is already set");
        _nftIdByType[info.objectType] = info.nftId;

        console.log("Registering stake");

        info.nftId = NftIdLib.toNftId(randomNumber(type(uint96).max));
        info.parentNftId = _nftIdByType[POOL()];
        info.objectType = STAKE();
        info.objectAddress = address(0);
        info.initialOwner = address(uint160(randomNumber(type(uint160).max)));

        _assert_register(info, false, "");
        assertEq(_nftIdByType[info.objectType].toInt(), 0, "Test error: _nftIdByType[STAKE] is already set");
        _nftIdByType[info.objectType] = info.nftId;
        // solhint-enable
    }
}