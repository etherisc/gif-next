// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";
import {IRelease} from "../registry/IRelease.sol";

abstract contract Registerable is
    AccessManagedUpgradeable,
    NftOwnable,
    IRegisterable
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.gif.Registerable@3.0.0")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REGISTERABLE_STORAGE_LOCATION_V3_0 = 0x66ed5788a8bec6ff1e7b389e8e939876404dd6c85eb5e16ebccc687f21cd6200;

    struct RegisterableStorage {
        NftId _parentNftId;
        ObjectType _objectType;
        bool _isInterceptor;
        bytes _data;
    }

    modifier onlyActive() {
        if (!isActive()) {
            revert ErrorRegisterableNotActive();
        }
        _;
    }

    function __Registerable_init(
        address authority,
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
        if (!ContractLib.isAuthority(authority)) {
            revert ErrorAuthorityInvalid(authority);
        }

        __AccessManaged_init(authority);
        __NftOwnable_init(registry, initialOwner);

        RegisterableStorage storage $ = _getRegisterableStorage();
        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._isInterceptor = isInterceptor;
        $._data = data;

        _registerInterface(type(IAccessManaged).interfaceId);
    }


    /// @inheritdoc IRegisterable
    function isActive() public virtual view returns (bool active) {
        return !AccessManagerCloneable(authority()).isTargetClosed(address(this));
    }


    /// @inheritdoc IRelease
    function getRelease() public virtual view returns (VersionPart release) {
        return AccessManagerCloneable(authority()).getRelease();
    }


    /// @inheritdoc IRegisterable
    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory info) 
    {
        RegisterableStorage storage $ = _getRegisterableStorage();
        return IRegistry.ObjectInfo(
            NftIdLib.zero(),
            $._parentNftId,
            $._objectType,
            $._isInterceptor,
            address(this), 
            getOwner(),
            $._data);
    }


    function _getRegisterableStorage() private pure returns (RegisterableStorage storage $) {
        assembly {
            $.slot := REGISTERABLE_STORAGE_LOCATION_V3_0
        }
    }
}