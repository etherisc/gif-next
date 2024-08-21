// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, STAKING} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";


abstract contract ComponentVerifyingService is 
    Service
{
    error ErrorComponentVerifyingServiceComponentTypeInvalid(NftId componentNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorComponentVerifyingServiceComponentIsLocked(NftId componentNftId);

    /// @dev based on the sender address returns the corresponding components nft id, info and instance.
    /// the function reverts iff:
    /// - there is no such component
    /// - the component has the wrong object type
    /// - the component is locked
    function _getAndVerifyActiveComponent(
        ObjectType expectedType // assume always of `component` type
    )
        internal
        view
        returns(
            NftId componentNftId,
            IRegistry.ObjectInfo memory objectInfo, 
            IInstance instance
        )
    {
        componentNftId = getRegistry().getNftIdForAddress(msg.sender);
        (objectInfo, instance) = _getAndVerifyComponentInfo(
            componentNftId, 
            expectedType,
            true); // only active
    }


    /// @dev returns the component info and instance contract reference given a component nft id
    /// the function reverts iff:
    /// - there is no such component
    /// - the component has the wrong object type
    function _getAndVerifyComponentInfo(
        NftId componentNftId,
        ObjectType expectedType, // assume always of `component` type
        bool onlyActive
    )
        internal
        virtual
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        IRegistry registry = getRegistry();
        info = registry.getObjectInfo(componentNftId);

        // if not COMPONENT require exact match
        if(expectedType != COMPONENT()) {
            // ensure component is of expected type
            if(info.objectType != expectedType) {
                revert ErrorComponentVerifyingServiceComponentTypeInvalid(
                    componentNftId,
                    expectedType,
                    info.objectType);
            }
        } else {
            if(!(info.objectType == PRODUCT()
                || info.objectType == POOL()
                || info.objectType == DISTRIBUTION()
                || info.objectType == ORACLE()
            ))
            {
                revert ErrorComponentVerifyingServiceComponentTypeInvalid(
                    componentNftId,
                    expectedType,
                    info.objectType);
            }
        }

        if (info.objectType == STAKING()) {
            return (info, instance);
        }
        
        if (info.objectType == PRODUCT()) {
            instance = _getInstance(registry, info.parentNftId);
        } else {
            instance = _getInstanceForComponent(registry, info.parentNftId);
        }

        // ensure component is not locked
        if (onlyActive) {
            if (instance.getInstanceAdmin().isTargetLocked(info.objectAddress)) {
                revert ErrorComponentVerifyingServiceComponentIsLocked(componentNftId);
            }
        }
    }


    function _getInstanceForComponent(IRegistry registry, NftId productNftId)
        internal
        view
        returns (IInstance instance)
    {
        return _getInstance(
                registry,
                registry.getObjectInfo(
                    productNftId).parentNftId);
    }


    /// @dev returns the product nft id from the registry.
    /// assumes the component nft id is valid and represents a product linked component.
    function _getProductNftId(NftId componentNftId) internal view returns (NftId productNftId) {
        productNftId = getRegistry().getParentNftId(componentNftId);
    }


    /// @dev returns an IInstance contract reference for the specified instance nft id
    function _getInstance(IRegistry registry, NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            registry.getObjectAddress(instanceNftId));
    }
}
