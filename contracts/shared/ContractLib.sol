// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "../shared/IService.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, PRODUCT, DISTRIBUTION, ORACLE, POOL, STAKING} from "../type/ObjectType.sol";
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

    error ErrorContractLibCallerNotRegistered(address target);
    error ErrorContractLibCallerNotComponent(NftId componentNftId, ObjectType objectType);
    error ErrorContractLibParentNotInstance(NftId componentNftId, NftId parentNftId);
    error ErrorContractLibParentNotProduct(NftId componentNftId, NftId parentNftId);
    error ErrorContractLibComponentTypeMismatch(NftId componentNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorContractLibComponentInactive(NftId componentNftId);


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
        return _getAndVerifyComponentAndInstance(registry, info, info.objectType, onlyActive);
    }


    function getAndVerifyAnyComponent(
        IRegistry registry, 
        address caller,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory callerInfo, 
            address instance
        )
    {
        // check caller is component
        callerInfo = _getAndVerifyObjectInfo(registry, caller);
        if(!(callerInfo.objectType == PRODUCT()
            || callerInfo.objectType == POOL()
            || callerInfo.objectType == DISTRIBUTION()
            || callerInfo.objectType == ORACLE())
        ) {
            revert ErrorContractLibCallerNotComponent(
                callerInfo.nftId,
                callerInfo.objectType);
        }

        return _getAndVerifyComponentAndInstance(registry, callerInfo, callerInfo.objectType, onlyActive);
    }


    function getAndVerifyComponent(
        IRegistry registry, 
        address caller,
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
        info = _getAndVerifyObjectInfo(registry, caller);
        return _getAndVerifyComponentAndInstance(registry, info, expectedType, onlyActive);
    }


    // TODO cleanup
    // function getAndVerifyStaking(
    //     IRegistry registry, 
    //     address target
    // )
    //     external
    //     view
    //     returns (IRegistry.ObjectInfo memory info)
    // {
    //     // check target is component
    //     info = _getAndVerifyObjectInfo(registry, target);
    //     if(info.objectType != STAKING()) {
    //         revert ErrorContractLibNotStaking(
    //             info.nftId,
    //             info.objectType);
    //     }
    // }


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


    function isProduct(address registry, address target)
        public
        view
        returns (bool)
    {
        if (!isInstanceLinkedComponent(registry, target)) {
            return false;
        }

        return IInstanceLinkedComponent(target).getInitialInfo().objectType == PRODUCT();
    }


    function isInstanceLinkedComponent(address registry, address target)
        public
        view
        returns (bool)
    {
        if (!isContract(target)) {
            return false;
        }

        return supportsInterface(target, type(IInstanceLinkedComponent).interfaceId);
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


    function _getAndVerifyComponentAndInstance(
        IRegistry registry, 
        IRegistry.ObjectInfo memory info,
        ObjectType expectedType,
        bool onlyActive
    )
        internal
        view
        returns (
            IRegistry.ObjectInfo memory, 
            address instance
        )
    {
        if(info.objectType != expectedType) {
            revert ErrorContractLibComponentTypeMismatch(
                info.nftId,
                expectedType,
                info.objectType);
        }

        // get instance and check component is active
        instance = getAndVerifyInstance(registry, info);
        _checkComponentActive(instance, info.objectAddress, info.nftId, onlyActive);

        return (
            info,
            instance
        );
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


    /// @dev Given an object info the function returns the instance address.
    /// The info may represent a product or any other component.
    /// If the parent of the provided info is not registered with the correct type, the function reverts.
    function getAndVerifyInstance(
        IRegistry registry,
        IRegistry.ObjectInfo memory info
    )
        public
        view
        returns (address instance)
    {
        // get instance for product case
        if (info.objectType == PRODUCT()) {
            // verify that parent of product is registered instance
            IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(info.parentNftId);
            if (instanceInfo.objectType != INSTANCE()) {
                revert ErrorContractLibParentNotInstance(
                    info.nftId,
                    info.parentNftId);
            }

            // we have verified that parent object is a registerd instance -> we return the instance address
            return instanceInfo.objectAddress;
        }

        // not product: verify parent is registered product
        info = registry.getObjectInfo(info.parentNftId);
        if (info.objectType != PRODUCT()) {
            revert ErrorContractLibParentNotProduct(
                info.nftId,
                info.parentNftId);
        }

        // we have verified that parent is registerd product -> we can rely on registry that its parent is an instance
        return registry.getObjectAddress(info.parentNftId);
    }


    function _getAndVerifyObjectInfo(
        IRegistry registry, 
        address caller
    )
        internal
        view
        returns (IRegistry.ObjectInfo memory info)
    {
        NftId componentNftId = registry.getNftIdForAddress(caller);
        if (componentNftId.eqz()) {
            revert ErrorContractLibCallerNotRegistered(caller);
        }

        info = registry.getObjectInfo(componentNftId);
    }
}