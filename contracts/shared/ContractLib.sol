// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, COMPONENT, PRODUCT, DISTRIBUTION, ORACLE, POOL, STAKING} from "../type/ObjectType.sol";
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

interface IRegisterableReleaseHelper {
    function getRelease() external view returns (VersionPart);
}

library ContractLib {

    error ErrorContractLibNotRegistered(address target);
    error ErrorContractLibNotRegisteredNftId(NftId targetNftId);
    error ErrorContractLibNotInstance(NftId notInstanceNftId, ObjectType objectType);
    error ErrorContractLibNotComponent(NftId notComponentNftId, ObjectType objectType);
    error ErrorContractLibNotStaking(NftId notStakingNftId, ObjectType objectType);
    error ErrorContractLibVersionMismatch(NftId targetNftId, VersionPart expectedVersion, VersionPart actualVersion);
    error ErrorContractLibTypeMismatch(NftId targetNftId, ObjectType expectedType, ObjectType actualType);
    error ErrorContractLibParentMismatch(NftId targetNftId, NftId expectedParentNftId, NftId actualParentNftId);
    error ErrorContractLibNotActive(address target);

    function getAndVerifyInstance(
        IRegistry registry,
        address instance,
        VersionPart requiredVersion,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info
        )
    {
        info = _getObjectInfo(registry, instance);

        _verifyContractInfo(
            info,
            INSTANCE(),
            requiredVersion
        );

        _checkContractActive(instance, info.objectAddress, info.nftId, onlyActive);
    }
    // TODO MUST be as fast as possible
    function getAndVerifyComponent(
        IRegistry registry, 
        address target,
        ObjectType requiredType,
        VersionPart requiredVersion,
        bool onlyActive
    )
        external
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            address instance
        )
    {
        info = _getObjectInfo(registry, target);
        instance = _getInstance(registry, info);

        _verifyContractInfo(
            info,
            requiredType,
            requiredVersion
        );

        _checkContractActive(instance, info.objectAddress, info.nftId, onlyActive);
    }

    function getAndVerifyComponentByNftId(
        IRegistry registry,
        NftId componentNftId,
        ObjectType requiredType,
        VersionPart requiredVersion,
        bool onlyActive
    )
        public
        view
        returns (
            IRegistry.ObjectInfo memory info, 
            address instance
        )
    {
        info = _getObjectInfo(registry, componentNftId);
        instance = _getInstance(registry, info);

        _verifyContractInfo(
            info,
            requiredType,
            requiredVersion
        );

        _checkContractActive(instance, info.objectAddress, info.nftId, onlyActive);
    }

    // msg.sender is parent of objectNftId AND checked against simple type
    //    PRODUCT-POLICY, POOL-BUNDLE, DISTRIBUTION-DISTRIBUTOR
    function getAndVerifyComponentForObject(
        IRegistry registry,
        address component,
        NftId objectNftId, 
        ObjectType requiredObjectType, // assume always of object type
        VersionPart requiredComponentVersion,
        bool onlyActive
    )
        external
        view
        returns (
            NftId componentNftId,
            address instance
        )
    {
        IRegistry.ObjectInfo memory componentInfo = _getObjectInfo(registry, component);
        IRegistry.ObjectInfo memory objectInfo = _getObjectInfo(registry, objectNftId);
        instance = _getInstance(registry, componentInfo);
        componentNftId = componentInfo.nftId;

        _verifyObjectInfo(
            objectInfo,
            requiredObjectType,
            componentNftId
        );

        // check component version
        // TODO check version with registry
        VersionPart componentVersion = IRegisterableReleaseHelper(
            componentInfo.objectAddress).getRelease();
        if(componentVersion != requiredComponentVersion) {
            revert ErrorContractLibVersionMismatch(
                componentInfo.nftId,
                requiredComponentVersion,
                componentVersion);
        }

        // check component is active
        _checkContractActive(instance, component, componentNftId, onlyActive);
    }

    // msg.sender have the same parent as objectNftId and is checked against collection of types (e.g. COMPONENT)
    //    ORACLE -> PRODUCT, POOL & ORACLE -> PRODUCT, POOL & POLICY -> PRODUCT
    function _getAndVerifyProductForComponentAndObject(
        IRegistry registry,
        address component,
        NftId objectNftId, 
        ObjectType requiredObjectType, // assume always of object type
        VersionPart requiredComponentVersion,
        bool onlyActive // for component -> TODO what about product?
    )
        external
        view
        returns (
            NftId productNftId,
            NftId componentNftId,
            address instance
        )
    {
        IRegistry.ObjectInfo memory componentInfo = _getObjectInfo(registry, component);
        IRegistry.ObjectInfo memory objectInfo = _getObjectInfo(registry, objectNftId);
        instance = _getInstance(registry, componentInfo);
        componentNftId = componentInfo.nftId;
        productNftId = componentInfo.objectType == PRODUCT() ? 
            componentInfo.nftId :
            componentInfo.parentNftId;


        _verifyObjectInfo(
            objectInfo,
            requiredObjectType,
            productNftId
        );

        // check component version
        // TODO check version with registry
        VersionPart componentVersion = IRegisterableReleaseHelper(
            componentInfo.objectAddress).getRelease();
        if(componentVersion != requiredComponentVersion) {
            revert ErrorContractLibVersionMismatch(
                componentInfo.nftId,
                requiredComponentVersion,
                componentVersion);
        }

        // check component is active
        _checkContractActive(instance, component, componentInfo.nftId, onlyActive);
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
        _checkContractActive(instance, info.objectAddress, info.nftId, onlyActive);
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

    function getInstanceForComponent(
        IRegistry registry, 
        NftId componentNftId
    )
        public
        view
        returns (address instance)
    {
        NftId productNftId = registry.getObjectInfo(componentNftId).parentNftId;
        NftId instanceNftId = registry.getObjectInfo(productNftId).parentNftId;
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

    // TODO store contract admin in ObjectInfo? -> to check if contract is active
    function _verifyContractInfo(
        IRegistry.ObjectInfo memory info,
        ObjectType requiredType,
        VersionPart requiredVersion
    )
        internal
        view
    {
        // check target type
        // if not COMPONENT require exact match
        if(requiredType != COMPONENT()) {
            if(info.objectType != requiredType) {
                revert ErrorContractLibTypeMismatch(
                    info.nftId,
                    requiredType,
                    info.objectType);
            }
        } else if(!(info.objectType == PRODUCT()
            || info.objectType == POOL()
            || info.objectType == DISTRIBUTION()
            || info.objectType == ORACLE())
        ) {
            revert ErrorContractLibNotComponent(
                info.nftId,
                info.objectType);
        }

        // check target version
        // TODO check version with registry
        VersionPart targetVersion = IRegisterableReleaseHelper(info.objectAddress).getRelease();
        if(targetVersion != requiredVersion) {
            revert ErrorContractLibVersionMismatch(
                info.nftId,
                requiredVersion,
                targetVersion);
        }
    }

    function _verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        ObjectType requiredType,
        NftId requiredParentNftId
    )
        internal
        pure
    {
        if(info.objectType != requiredType) {
            revert ErrorContractLibTypeMismatch(
                info.nftId,
                requiredType,
                info.objectType);
        }

        if(info.parentNftId != requiredParentNftId) {
            revert ErrorContractLibParentMismatch(
                info.nftId, 
                requiredParentNftId,
                info.parentNftId);
        }
    }

    function _checkContractActive(
        address instance, 
        address component, 
        NftId componentNftId, 
        bool onlyActive
    )
        internal
        view
    {
        if (onlyActive) {
            if (IInstanceAdminHelper(
                instance).getInstanceAdmin().isTargetLocked(
                    component)
            ) {
                revert ErrorContractLibNotActive(component);
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
        info = registry.getObjectInfo(target);

        if (info.nftId.eqz()) {
            revert ErrorContractLibNotRegistered(target);
        }
    }

    function _getObjectInfo(
        IRegistry registry, 
        NftId objectNftId
    )
        internal
        view
        returns (IRegistry.ObjectInfo memory info)
    {
        info = registry.getObjectInfo(objectNftId);

        if (info.nftId.eqz()) {
            revert ErrorContractLibNotRegisteredNftId(objectNftId);
        }
    }
}