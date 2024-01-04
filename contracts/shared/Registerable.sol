// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {NftId, zeroNftId} from "../types/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {ObjectType} from "../types/ObjectType.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";
import {Versionable} from "./Versionable.sol";

import {ERC165} from "./ERC165.sol";

contract Registerable is
    ERC165,
    Initializable,
    NftOwnable,
    IRegisterable
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Registerable.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_LOCATION_V1 = 0x6548007c3f4340f82f348c576c0ff69f4f529cadd5ad41f96aae61abceeaa300;

    error ErrorRegisterableNotRegistry(address registryAddress);

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

    function _initializeRegisterable(
        address registryAddress,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        internal
        //onlyInitializing//TODO uncomment when "fully" upgradeable
        virtual
    {
        _initializeNftOwnable(
            initialOwner,
            registryAddress);

        // TODO check parentNftId -> registry.isRegistered(parentNftId)
        // TODO check object-parent type pair -> registry.isValidTypeCombo() or something...verify with registry that setup will be able to register...

        RegisterableStorage storage $ = _getRegisterableStorage();
        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._isInterceptor = isInterceptor;
        $._data = data;

        _registerInterface(type(IRegisterable).interfaceId);
    }


    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory, bytes memory data) 
    {
        RegisterableStorage storage $ = _getRegisterableStorage();
        return (
            IRegistry.ObjectInfo(
                zeroNftId(),
                $._parentNftId,
                $._objectType,
                $._isInterceptor,
                address(this), 
                getOwner(),
                $._data
            ),
            bytes("")
        );
    }
}