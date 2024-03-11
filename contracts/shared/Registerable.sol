// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {NftId, zeroNftId} from "../types/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";
import {Versionable} from "./Versionable.sol";

contract Registerable is
    NftOwnable,
    IRegisterable
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Registerable.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    struct RegisterableStorage {
        NftId _parentNftId;
        ObjectType _objectType;
        bool _isInterceptor;
        bytes _data;
    }

    function _getRegisterableStorage() private pure returns (RegisterableStorage storage $) {
        assembly {
            $.slot := REGISTERABLE_LOCATION_V1
        }
    }

    function initializeRegisterable(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        public
        virtual
        onlyInitializing
    {
        initializeNftOwnable(
            initialOwner,
            registryAddress);

        RegisterableStorage storage $ = _getRegisterableStorage();
        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._isInterceptor = isInterceptor;
        $._data = data;
    }


    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory info) 
    {
        RegisterableStorage memory $ = _getRegisterableStorage();
        info = IRegistry.ObjectInfo(
            zeroNftId(),
            $._parentNftId,
            $._objectType,
            $._isInterceptor,
            address(this), 
            getOwner(),
            $._data);
    }
}