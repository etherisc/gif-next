// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IInstance} from "../instance/IInstance.sol";
import {IOracleComponent} from "../oracle/IOracleComponent.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IService} from "../shared/IService.sol";

import {ChainId} from "../type/ChainId.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, COMPONENT, PRODUCT, DISTRIBUTION, ORACLE, POOL, POLICY, BUNDLE} from "../type/ObjectType.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {VersionPart} from "../type/Version.sol";

interface ITargetHelper {
    function isTargetLocked(address target) external view returns (bool);
}

library ContractLib {

    error ErrorContractLibCallerNotRegistered(address caller);
    error ErrorContractLibCallerNotComponent(/*address caller, */NftId callerNftId, ObjectType callerType);
    error ErrorContractLibParentNotInstance(/*address component, */NftId componentNftId, NftId parentNftId/*, ObjectType parentType*/);
    error ErrorContractLibParentNotProduct(/*address component, */NftId componentNftId, NftId parentNftId/*, ObjectType parentType*/);
    error ErrorContractLibComponentTypeMismatch(/*address component, */NftId componentNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorContractLibComponentReleaseMismatch(/*address component, */NftId componentNftId, VersionPart expectedRelease, VersionPart actualRelease);
    error ErrorContractLibComponentInactive(/*address component, */NftId componentNftId);

    error ErrorContractLibObjectNotRegistered(NftId objectNftId);
    error ErrorContractLibObjectTypeMismatch(NftId objectNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorContractLibObjectReleaseMismatch(NftId objectNftId, VersionPart expectedRelease, VersionPart actualRelease);
    error ErrorContractLibObjectParentMismatch(NftId objectNftId, NftId expectedParentNftId, NftId actualParentNftId);

    error ErrorContractLibParentsMismatch(NftId componentNftId, NftId componentParentNftId, NftId objectNftId, NftId objectParentNftId);



    // update registry address whenever it changes
    address public constant REGISTRY_ADDRESS = address(0x345cA3e014Aaf5dcA488057592ee47305D9B3e10);

    function getRegistry() internal pure returns (IRegistry) {
        return IRegistry(REGISTRY_ADDRESS);
    }

    function getAndVerifyProduct(VersionPart expectedRelease)
        external
        view
        returns (
            NftId, // productNftId
            IInstance // instance,
        )
    {
        return getAndVerifyComponent(
            msg.sender,
            PRODUCT(),
            expectedRelease,
            true); // only active product
    }

    function getAndVerifyPool(VersionPart expectedRelease)
        external
        view
        returns (
            NftId, // poolNftId
            IInstance // instance,
        )
    {
        return getAndVerifyComponent(
            msg.sender,
            POOL(),
            expectedRelease,
            true); // only active pool
    }

    function getAndVerifyProductForPolicy(NftId policyNftId, VersionPart expectedRelease)
        external
        view
        returns (
            NftId, // productNftId
            IInstance // instance,
        )
    {
        return getAndVerifyComponentWithChild(
            msg.sender, // product
            true, // only active product
            policyNftId, // child nft id
            POLICY(), // child must be policy
            expectedRelease);
    }

    function getAndVerifyPoolForBundle(NftId bundleNftId, VersionPart expectedRelease)
        external
        view
        returns (
            NftId, // poolNftId
            IInstance // instance,
        )
    {
        return getAndVerifyComponentWithChild({
            component: msg.sender, // pool 
            onlyActive: true, // only active pool
            childNftId: bundleNftId, // child nft id
            expectedChildType: BUNDLE(), // child must be bundle
            expectedRelease: expectedRelease});
    }

    function getAndVerifyPoolForPolicy(NftId policyNftId, VersionPart expectedRelease)
        external
        view
        returns (
            NftId poolNftId,
            IInstance instance
        )
    {
        (poolNftId,, instance) = getAndVerifyComponentAndObject({
            component: msg.sender,  // pool
            expectedComponentType: POOL(),
            onlyActive: true,
            objectNftId: policyNftId,
            expectedObjectType: POLICY(),
            expectedRelease: expectedRelease
        });    
    }

    function getAndVerifyComponentAndOracle(
        NftId oracleNftId,
        VersionPart expectedRelease
    )
        external
        view
        returns (
            NftId requesterNftId,
            IOracleComponent oracle,
            IInstance instance
        )
    {
        address oracleAddress;
        (requesterNftId, oracleAddress, instance) = getAndVerifyComponentAndObject({
            component: msg.sender,
            expectedComponentType: COMPONENT(),
            onlyActive: true, 
            objectNftId: oracleNftId,
            expectedObjectType: ORACLE(),
            expectedRelease: expectedRelease
        });

        oracle = IOracleComponent(oracleAddress);
    }


    function getInfoAndInstance(
        NftId componentNftId,
        VersionPart release,
        bool onlyActive
    )
        public
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        IRegistry registry = getRegistry();
        info = registry.getObjectInfo(componentNftId);
        (, instance) = _getAndVerifyComponentAndInstance(info, info.objectType, release, onlyActive);
    }


    function getAndVerifyComponent(
        address caller,
        ObjectType expectedType,
        VersionPart expectedRelease,
        bool onlyActive
    )
        public
        view
        returns (
            NftId componentNftId, 
            IInstance instance
        )
    {
        // check caller is registered
        IRegistry.ObjectInfo memory info = _getAndVerifyObjectInfo(caller);
        // check caller info
        return _getAndVerifyComponentAndInstance(info, expectedType, expectedRelease, onlyActive);
    }

    function getAndVerifyComponentWithChild(
        address component,
        bool onlyActive, 
        NftId childNftId, 
        ObjectType expectedChildType, // assume valid component type
        VersionPart expectedRelease
    ) 
        public
        view
        returns (
            //IRegistry.ObjectInfo memory info,  // component info
            NftId componentNftId,
            IInstance instance)
    {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(childNftId);

        // check child registration
        if(info.nftId.eqz()) {
            revert ErrorContractLibObjectNotRegistered(childNftId);
        }

        // check child type
        if(info.objectType != expectedChildType) {
            revert ErrorContractLibObjectTypeMismatch(
                childNftId, 
                expectedChildType, 
                info.objectType);
        }

        // check child release
        if(info.release != expectedRelease) {
            revert ErrorContractLibObjectReleaseMismatch(
                childNftId, 
                expectedRelease, 
                info.release);
        }

        info = registry.getObjectInfo(info.parentNftId);
        componentNftId = info.nftId;

        // check parent is component
        if(info.objectAddress != component) {
            revert ErrorContractLibObjectParentMismatch(
                childNftId,
                registry.getNftIdForAddress(component),
                info.nftId);
        }

        // get instance
        instance = getAndVerifyInstance(info);// _getAndVerifyInstance(info);

        // check component is active
        _checkComponentActive(
            instance, 
            component, 
            componentNftId, 
            onlyActive);
    }

    /// @dev 
    // component is contract of type COMPONENT
    // objectNftId is either contract of type COMPONENT or object of type POLICY, BUNDLE, etc.
    //             is either child of component or have same parent as component
    function getAndVerifyComponentAndObject(
        address component,
        ObjectType expectedComponentType,
        bool onlyActive, 
        NftId objectNftId,
        ObjectType expectedObjectType,
        VersionPart expectedRelease
    )
        public
        view
        returns (
            NftId componentNftId,
            address objectAddress, // 0 for non contracts objects
            IInstance instance)
    {
        IRegistry registry = getRegistry();

        IRegistry.ObjectInfo memory componentInfo = registry.getObjectInfo(component);
        componentNftId = componentInfo.nftId;

        // check component registered 

        // check component type
        if(expectedComponentType != COMPONENT()) {
            if(componentInfo.objectType != expectedComponentType) {
                revert ErrorContractLibComponentTypeMismatch(
                    //component,
                    componentInfo.nftId,
                    expectedComponentType,
                    componentInfo.objectType);
            }
        } else if(
            !(
                componentInfo.objectType == PRODUCT() ||
                componentInfo.objectType == POOL() ||
                componentInfo.objectType == DISTRIBUTION() ||
                componentInfo.objectType == ORACLE()
            )
        ) {
            revert ErrorContractLibCallerNotComponent(
                //component,
                componentInfo.nftId,
                componentInfo.objectType);
        }

        // check component release
        if(componentInfo.release != expectedRelease) {
            revert ErrorContractLibComponentReleaseMismatch(
                //component, 
                componentInfo.nftId, 
                expectedRelease, 
                componentInfo.release);
        }

        IRegistry.ObjectInfo memory objectInfo = registry.getObjectInfo(objectNftId);
        objectAddress = objectInfo.objectAddress;

        // check object type
        if(objectInfo.objectType != expectedObjectType) {
            revert ErrorContractLibObjectTypeMismatch(
                objectNftId, 
                expectedObjectType, 
                objectInfo.objectType);
        }

        if(componentInfo.objectType == PRODUCT()) {
            // check object parent is product
            if(componentInfo.nftId != objectInfo.parentNftId) {
                revert ErrorContractLibObjectParentMismatch(
                    objectNftId,
                    objectInfo.parentNftId,
                    componentInfo.nftId);
            }
        } else {
            // check component parent is product

            // check object parent is same product
            if(componentInfo.parentNftId != objectInfo.parentNftId) {
                revert ErrorContractLibParentsMismatch(
                    componentInfo.nftId,
                    componentInfo.parentNftId,
                    objectNftId, 
                    objectInfo.parentNftId);
            }
        }

        // get instance
        instance = getAndVerifyInstance(componentInfo);

        // check component is active
        _checkComponentActive(
            instance, 
            component, 
            componentNftId, 
            onlyActive);
    }


    function getInstanceForComponent(
        NftId componentNftId
    )
        public
        view
        returns (address instance)
    {
        IRegistry registry = getRegistry();
        NftId productNftId = registry.getParentNftId(componentNftId);
        NftId instanceNftId = registry.getParentNftId(productNftId);
        return registry.getObjectInfo(instanceNftId).objectAddress;
    }

    // TODO check array of nfts and array of types
    //      need to call: checkNftType({nftId: {nftId1, nftId2, nftId3}, expectedObjectType: {.., .., ..}})
    /*function checkNftType(NftId nftId, ObjectType expectedObjectType) external view {
        VersionPart expectedRelease = getRelease();
        if(expectedObjectType.eqz() || !_getRegistry().isObjectType(nftId, expectedObjectType, expectedRelease)) {
            revert ErrorNftOwnableInvalidType(nftId, expectedObjectType, expectedRelease);
        }
    }*/

    // TODO hardcoded token registry address?
    function isActiveToken(
        address tokenRegistryAddress,
        ChainId chainId, 
        address token,
        VersionPart release
    )
        external 
        view 
        returns (bool)
    {
        return TokenRegistry(
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


    function isService(address service) public view returns (bool) {
        if (!isContract(service)) {
            return false;
        }

        return supportsInterface(service, type(IService).interfaceId);
    }


    function isRegistry(address registry) public pure returns (bool) {
        return registry == REGISTRY_ADDRESS;
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
        IRegistry.ObjectInfo memory info,
        ObjectType expectedType,
        VersionPart expectedRelease,
        bool onlyActive
    )
        internal
        view
        returns (
            NftId componentNftId,
            IInstance instance
        )
    {
        if(expectedType != COMPONENT()) {
            if(info.objectType != expectedType) {
                revert ErrorContractLibComponentTypeMismatch(
                    //info.objectAddress,
                    info.nftId,
                    expectedType,
                    info.objectType);
            }
        } else if(
            !(
                info.objectType == PRODUCT() ||
                info.objectType == POOL() ||
                info.objectType == DISTRIBUTION() ||
                info.objectType == ORACLE()
            )
        ) {
            revert ErrorContractLibCallerNotComponent(
                //info.objectAddress,
                info.nftId,
                info.objectType);
        }

        if(info.release != expectedRelease) {
            revert ErrorContractLibComponentReleaseMismatch(
                //info.objectAddress,
                info.nftId,
                expectedRelease,
                info.release);
        }

        componentNftId = info.nftId;

        // get instance and check component is active
        instance = getAndVerifyInstance(info);
        _checkComponentActive(instance, info.objectAddress, info.nftId, onlyActive);
    }


    function _checkComponentActive(
        IInstance instance, 
        address component, 
        NftId componentNftId, 
        bool onlyActive
    )
        internal
        view
    {
        if (onlyActive) {
            if (instance.getInstanceAdmin().isTargetLocked(component)) {
                revert ErrorContractLibComponentInactive(/*component, */componentNftId);
            }
        }
    }


    /// @dev Given an object info the function returns the instance address.
    /// The info may represent a product or any other component.
    /// If the parent of the provided info is not registered with the correct type, the function reverts.
    function getAndVerifyInstance(
        IRegistry.ObjectInfo memory info
    )
        public
        view
        returns (IInstance instance)
    {
        IRegistry registry = getRegistry();

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
            return IInstance(instanceInfo.objectAddress);
        }

        // not product: verify parent is registered product
        info = registry.getObjectInfo(info.parentNftId);
        if (info.objectType != PRODUCT()) {
            revert ErrorContractLibParentNotProduct(
                info.nftId,
                info.parentNftId);
        }

        // we have verified that parent is registerd product -> we can rely on registry that its parent is an instance
        return IInstance(registry.getObjectAddress(info.parentNftId));
    }

    // check registration and return info
    function _getAndVerifyObjectInfo(
        address caller
    )
        internal
        view
        returns (IRegistry.ObjectInfo memory info)
    {
        IRegistry registry = getRegistry();

        info = registry.getObjectInfo(caller);

        if (info.nftId.eqz()) {
            revert ErrorContractLibCallerNotRegistered(caller);
        }
    }
}