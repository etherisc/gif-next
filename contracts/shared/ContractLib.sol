// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

// import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "../shared/IService.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType, PRODUCT, DISTRIBUTION, ORACLE, POOL, STAKING} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";

interface ITargetHelper {
    function isTargetLocked(address target) external view returns (bool);
}

interface IInstanceAdminHelper {
    function getInstanceAdmin() external view returns (ITargetHelper);
}

interface ITokenRegistryHelper {
    function isActive(uint256 chainId, address token, VersionPart release) external view returns (bool);
}

library ContractLib {

    error ErrorContractLibNotRegistered(address target);
    error ErrorContractLibNotComponent(NftId componentNftId, ObjectType objectType);
    error ErrorContractLibNotStaking(NftId componentNftId, ObjectType objectType);
    error ErrorContractLibComponentTypeMismatch(NftId componentNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorContractLibComponentInactive(NftId componentNftId);

    function getAndVerifyComponent(
        IRegistry registry, 
        address target,
        ObjectType expectedType,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            address instance
        )
    {
        // check target is component
        info = _getObjectInfo(registry, target);
        if(info.objectType != expectedType) {
            revert ErrorContractLibComponentTypeMismatch(
                info.nftId,
                expectedType,
                info.objectType);
        }

        // get instance and check component is active
        instance = _getInstance(registry, info);
        _checkComponentActive(instance, target, info.nftId, onlyActive);
    }


    function getInfoAndInstance(
        IRegistry registry,
        NftId componentNftId,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            address instance
        )
    {
        info = registry.getObjectInfo(componentNftId);
        instance = _getInstance(registry, info);
        _checkComponentActive(instance, info.objectAddress, info.nftId, onlyActive);
    }


    function getAndVerifyStaking(
        IRegistry registry, 
        address target
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info
        )
    {
        // check target is component
        info = _getObjectInfo(registry, target);
        if(info.objectType != STAKING()) {
            revert ErrorContractLibNotStaking(
                info.nftId,
                info.objectType);
        }
    }


    function getAndVerifyAnyComponent(
        IRegistry registry, 
        address target,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            address instance
        )
    {
        // check target is component
        info = _getObjectInfo(registry, target);
        if(!(info.objectType == PRODUCT()
            || info.objectType == POOL()
            || info.objectType == DISTRIBUTION()
            || info.objectType == ORACLE())
        ) {
            revert ErrorContractLibNotComponent(
                info.nftId,
                info.objectType);
        }

        // get instance and check component is active
        instance = _getInstance(registry, info);
        _checkComponentActive(instance, target, info.nftId, onlyActive);
    }


    function getInstanceForComponent(
        IRegistry registry, 
        NftId componentNftId
    )
        public
        view
        returns (address instance)
    {
        NftId productNftId = registry.getParentNftId(componentNftId);
        NftId instanceNftId = registry.getParentNftId(productNftId);
        return registry.getObjectInfo(instanceNftId).objectAddress;
    }


    function isActiveToken(
        address tokenRegistryAddress,
        address token,
        uint256 chainId, 
        VersionPart release
    )
        external 
        view 
        returns (bool)
    {
        return ITokenRegistryHelper(
            tokenRegistryAddress).isActive(
                chainId, token, release);
    }

    function isPolicyHolder(address target) external view returns (bool) {
        return ERC165Checker.supportsInterface(target, type(IPolicyHolder).interfaceId);
    }


    function isAuthority(address authority) public view returns (bool) {
        if (!isContract(authority)) {
            return false;
        }

        return supportsInterface(authority, type(IAccessManager).interfaceId);
    }


    function isAccessManaged(address target)
        public
        view
        returns (bool)
    {
        if (!isContract(target)) {
            return false;
        }

        (bool success, ) = target.staticcall(
            abi.encodeWithSelector(
                IAccessManaged.authority.selector));

        return success;
    }


    function isRegistered(address registry, address caller, ObjectType expectedType) public view returns (bool) {
        NftId nftId = IRegistry(registry).getNftIdForAddress(caller);
        if (nftId.eqz()) {
            return false;
        }

        return IRegistry(registry).getObjectInfo(nftId).objectType == expectedType;
    }


    function isService(address service) public view returns (bool) {
        if (!isContract(service)) {
            return false;
        }

        return supportsInterface(service, type(IService).interfaceId);
    }


    function isRegistry(address registry) public view returns (bool) {
        if (!isContract(registry)) {
            return false;
        }

        return supportsInterface(registry, type(IRegistry).interfaceId);
    }


    function isContract(address target) public view returns (bool) {
        if (target == address(0)) {
            return false;
        }

        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        return size > 0;
    }

    function supportsInterface(address target, bytes4 interfaceId)  public view returns (bool) {
        return ERC165Checker.supportsInterface(target, interfaceId);
    }


    function _checkComponentActive(
        address instance, 
        address target, 
        NftId componentNftId, 
        bool onlyActive
    )
        internal
        view
    {
        if (onlyActive) {
            if (IInstanceAdminHelper(
                instance).getInstanceAdmin().isTargetLocked(
                    target)
            ) {
                revert ErrorContractLibComponentInactive(componentNftId);
            }
        }
    }


    function _getInstance(
        IRegistry registry,
        IRegistry.ObjectInfo memory info
    )
        internal
        view
        returns (address instance)
    {
        if (info.objectType == PRODUCT()) {
            return registry.getObjectAddress(
                info.parentNftId);
        } 
        
        return registry.getObjectAddress(
                registry.getObjectInfo(
                    info.parentNftId).parentNftId);
    }


    function _getObjectInfo(
        IRegistry registry, 
        address target
    )
        internal
        view
        returns (IRegistry.ObjectInfo memory info)
    {
        NftId componentNftId = registry.getNftIdForAddress(target);
        if (componentNftId.eqz()) {
            revert ErrorContractLibNotRegistered(target);
        }

        info = registry.getObjectInfo(componentNftId);
    }
}