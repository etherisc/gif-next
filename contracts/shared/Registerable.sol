// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";

contract Registerable is
    NftOwnable,
    IRegisterable
{
    uint256 public constant GIF_RELEASE = 3;

    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Registerable.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    struct RegisterableStorage {
        NftId _parentNftId;
        ObjectType _objectType;
        bool _isInterceptor;
        bytes _data;
    }

    function _initializeRegisterable(
        address registry,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data // writeonly data that will saved in the object info record of the registry
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeNftOwnable(
            registry,
            initialOwner);

        RegisterableStorage storage $;
        assembly {
            $.slot := REGISTERABLE_LOCATION_V1
        }

        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._isInterceptor = isInterceptor;
        $._data = data;
    }


    /// @inheritdoc IRegisterable
    function getRelease() public virtual pure returns (VersionPart release) {
        return VersionPartLib.toVersionPart(GIF_RELEASE);
    }


    /// @inheritdoc IRegisterable
    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory info) 
    {
        RegisterableStorage storage $;
        assembly {
            $.slot := REGISTERABLE_LOCATION_V1
        }

        info = IRegistry.ObjectInfo(
            NftIdLib.zero(),
            $._parentNftId,
            $._objectType,
            $._isInterceptor,
            address(this), 
            getOwner(),
            $._data);
    }
}