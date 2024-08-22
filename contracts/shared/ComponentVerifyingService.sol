// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, DISTRIBUTION, ORACLE, POOL, PRODUCT, STAKING} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";


abstract contract ComponentVerifyingService is 
    Service
{
    function _getAndVerifyCallingInstance()
        internal
        view
        returns (
            NftId instanceNftId,
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {

        info = ContractLib.getAndVerifyInstance(
            getRegistry(), msg.sender, getRelease(), true);

        instanceNftId = info.nftId;
        instance = IInstance(msg.sender);
    }

    /// @dev based on the sender address returns the corresponding components nft id, info and instance.
    /// the function reverts iff:
    /// - there is no such component
    /// - the component has the wrong object type
    /// - the component has wrong version
    /// - the component is locked/unlocked
    function _getAndVerifyCallingComponent(ObjectType expectedType, bool onlyActive) 
        internal 
        view 
        returns (
            NftId componentNftId,
            IRegistry.ObjectInfo memory info,
            IInstance instance
        )
    {
        address instanceAddress;
        (info, instanceAddress) = ContractLib.getAndVerifyComponent(
            getRegistry(), msg.sender, expectedType, getRelease(), onlyActive);

        // get component nft id and instance
        componentNftId = info.nftId;
        instance = IInstance(instanceAddress);
    }

    /// @dev returns the component info and instance contract reference given a component nft id
    /// the function reverts iff:
    /// - there is no such component
    /// - the component has the wrong object type
    function _getAndVerifyComponentByNftId(
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
        address instanceAddress;
        (info, instanceAddress) = ContractLib.getAndVerifyComponentByNftId(
            getRegistry(), componentNftId, expectedType, getRelease(), onlyActive);

        instance = IInstance(instanceAddress);
    }

    function _getAndVerifyCallingComponentForObject(NftId objectNftId, ObjectType objectType)
        internal
        virtual
        view
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        address instanceAddress;
        (
            componentNftId, 
            instanceAddress
        ) = ContractLib.getAndVerifyComponentForObject(
                getRegistry(), msg.sender, objectNftId, objectType, getRelease(), true); // only active caller

        instance = IInstance(instanceAddress);
    }

    // TODO better naming
    function _getAndVerifyComponentAndObjectHaveSameProduct(NftId objectNftId, ObjectType objectType)
        internal
        virtual
        view
        returns (
            NftId productNftId,
            NftId componentNftId,
            IInstance instance
        )
    {
        address instanceAddress;
        (
            productNftId,
            componentNftId,
            instanceAddress
        ) = ContractLib._getAndVerifyProductForComponentAndObject(
                getRegistry(), msg.sender, objectNftId, objectType, getRelease(), true); // only active caller

        instance = IInstance(instanceAddress);
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
        productNftId = getRegistry().getObjectInfo(componentNftId).parentNftId;
    }


    /// @dev returns an IInstance contract reference for the specified instance nft id
    function _getInstance(IRegistry registry, NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            registry.getObjectAddress(instanceNftId));
    }
}
