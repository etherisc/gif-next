// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ComponentServiceHelperLib} from "./ComponentServiceHelperLib.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IProductComponent} from "../product/IProductComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, REGISTRY, BUNDLE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, INSTANCE, ORACLE, POOL, PRODUCT} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {TokenHandlerDeployerLib} from "../shared/TokenHandlerDeployerLib.sol";


library ComponentServiceHelperLib {

    /// @dev Based on the provided component address required type the component 
    /// and related instance contract this function reverts iff:
    /// - the sender is not registered
    /// - the component contract does not support IInstanceLinkedComponent
    /// - the component type does not match with the required type
    /// - the component has already been registered
    function getAndVerifyRegisterableComponent(
        IRegistry registry,
        address componentAddress,
        ObjectType requiredType
    )
        public
        view
        returns (
            NftId instanceNftId,
            IInstance instance,
            NftId parentNftId,
            IInstanceLinkedComponent component,
            address initialOwner
        )
    {
        // check sender (instance or product) is registered
        IRegistry.ObjectInfo memory senderInfo = registry.getObjectInfo(msg.sender);
        if (senderInfo.nftId.eqz()) {
            revert IComponentService.ErrorComponentServiceSenderNotRegistered(msg.sender);
        }

        // the sender is the parent of the component to be registered
        // an instance caller wanting to register a product - or -
        // a product caller wantint go register a distribution, oracle or pool
        parentNftId = senderInfo.nftId;

        // check component is of required type
        component = IInstanceLinkedComponent(componentAddress);
        IRegistry.ObjectInfo memory info = component.getInitialInfo();
        if(info.objectType != requiredType) {
            revert IComponentService.ErrorComponentServiceInvalidType(componentAddress, requiredType, info.objectType);
        }

        // check component has not already been registered
        if (registry.getNftIdForAddress(componentAddress).gtz()) {
            revert IComponentService.ErrorComponentServiceAlreadyRegistered(componentAddress);
        }

        // check release matches
        address parentAddress = registry.getObjectAddress(parentNftId);
        if (component.getRelease() != IRegisterable(parentAddress).getRelease()) {
            revert IComponentService.ErrorComponentServiceReleaseMismatch(componentAddress, component.getRelease(), IRegisterable(parentAddress).getRelease());
        }

        // check component belongs to same product cluster 
        // parent of product must be instance, parent of other componet types must be product
        if (info.parentNftId != senderInfo.nftId) {
            revert IComponentService.ErrorComponentServiceSenderNotComponentParent(senderInfo.nftId, info.parentNftId);
        }

        // verify parent is registered instance
        if (requiredType == PRODUCT()) {
            if (senderInfo.objectType != INSTANCE()) {
                revert IComponentService.ErrorComponentServiceParentNotInstance(senderInfo.nftId, senderInfo.objectType);
            }

            instanceNftId = senderInfo.nftId;
        // verify parent is registered product
        } else {
            if (senderInfo.objectType != PRODUCT()) {
                revert IComponentService.ErrorComponentServiceParentNotProduct(senderInfo.nftId, senderInfo.objectType);
            }

            instanceNftId = senderInfo.parentNftId;
        }

        // get initial owner and instance
        initialOwner = info.initialOwner;
        instance = _getInstance(registry, instanceNftId);
    }

    /// @dev returns an IInstance contract reference for the specified instance nft id
    function _getInstance(IRegistry registry, NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            registry.getObjectAddress(instanceNftId));
    }

}