// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Versionable} from "../shared/Versionable.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "./IRegisterable.sol";

abstract contract Registerable is
    AccessManagedUpgradeable,
    NftOwnable,
    Versionable,
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

    modifier onlyActive() {
        if (!isActive()) {
            revert ErrorRegisterableNotActive();
        }
        _;
    }

    // TODO move to registerables verification library
    modifier onlyNftOfType(NftId nftId, ObjectType expectedObjectType) {
        _checkNftType(nftId, expectedObjectType);
        _;
    }

    // TODO move to registerables verification library
    function _checkNftType(NftId nftId, ObjectType expectedObjectType) internal view {
        if(expectedObjectType.eqz() || !getRegistry().isObjectType(nftId, expectedObjectType, getRelease())) {
            revert ErrorNftOwnableInvalidType(nftId, expectedObjectType);
        }
    }

    function __Registerable_init(
        address authority,
        address registry,
        NftId parentNftId,
        ObjectType objectType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        internal
        virtual
        onlyInitializing()
    {
        if (!ContractLib.isAuthority(authority)) {
            revert ErrorAuthorityInvalid(authority);
        }

        // release must allign with authority -> not a release check of third contract...
        VersionPart release = AccessManagerCloneable(authority).getRelease();

        __AccessManaged_init(authority);
        __NftOwnable_init(registry, initialOwner);
        __Versionable_init(release);

        RegisterableStorage storage $ = _getRegisterableStorage();
        $._parentNftId = parentNftId;
        $._objectType = objectType;
        $._isInterceptor = isInterceptor;
        if(data.length > 0) { 
            $._data = data;
        }

        _registerInterface(type(IAccessManaged).interfaceId);
    }


    /// @inheritdoc IRegisterable
    function isActive() public virtual view returns (bool active) {
        return !AccessManagerCloneable(authority()).isTargetClosed(address(this));
    }

    /// @inheritdoc IRegisterable
    function getInitialInfo() 
        public 
        view 
        virtual 
        returns (IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) 
    {
        RegisterableStorage storage $ = _getRegisterableStorage();
        return (
            IRegistry.ObjectInfo(
                NftIdLib.zero(),
                $._parentNftId,
                $._objectType,
                getRelease(),
                $._isInterceptor,
                address(this)),
            getOwner(),
            $._data
        );
    }


    function _getRegisterableStorage() private pure returns (RegisterableStorage storage $) {
        assembly {
            $.slot := REGISTERABLE_LOCATION_V1
        }
    }
}