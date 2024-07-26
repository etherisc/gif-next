// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";


abstract contract ComponentVerifyingService is 
    Service
{

    error ErrorComponentVerifyingServiceComponentTypeInvalid(NftId componentNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorComponentVerifyingServiceComponentIsLocked(NftId componentNftId);
    error ErrorNftNotObjectType(NftId nftId, ObjectType objectType, ObjectType expectedObjectType);

    modifier onlyNftObjectType(NftId nftId, ObjectType expectedObjectType) {
        ObjectType objectType = getRegistry().getObjectInfo(nftId).objectType;
        if(!objectType.eq(expectedObjectType)) {
            revert ErrorNftNotObjectType(nftId, objectType, expectedObjectType);
        }
        _;
    }

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
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        )
    {
        componentNftId = getRegistry().getNftIdForAddress(msg.sender);
        (componentInfo, instance) = _getAndVerifyComponentInfo(
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

        instance = _getInstance(info.parentNftId);

        // ensure component is not locked
        if (onlyActive) {
            if (instance.getInstanceAdmin().isTargetLocked(info.objectAddress)) {
                revert ErrorComponentVerifyingServiceComponentIsLocked(componentNftId);
            }
        }
    }


    /// @dev returns the linked product nft id for the specified component
    function _getProductNftId(
        InstanceReader instanceReader,
        NftId componentNftId
    )
        internal
        virtual
        view
        returns (NftId productNftId)
    {
        return instanceReader.getComponentInfo(componentNftId).productNftId;
    }


    /// @dev returns an IInstance contract reference for the specified instance nft id
    function _getInstance(NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            getRegistry().getObjectAddress(instanceNftId));
    }
}
