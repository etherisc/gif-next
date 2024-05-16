// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {RiskId} from "../type/RiskId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT, DISTRIBUTOR, DISTRIBUTOR_TYPE} from "../type/ObjectType.sol";
import {RoleId, RoleIdLib, eqRoleId, ADMIN_ROLE, INSTANCE_ROLE, INSTANCE_OWNER_ROLE} from "../type/RoleId.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ReferralId} from "../type/Referral.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {DistributorType} from "../type/DistributorType.sol";

import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {AccessManagerExtendedInitializeable} from "../shared/AccessManagerExtendedInitializeable.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";

import {KeyValueStore} from "../shared/KeyValueStore.sol";

import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";

import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IProductService} from "../product/IProductService.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {IBundleService} from "../pool/IBundleService.sol";

contract Instance is
    IInstance,
    AccessManagedUpgradeable,
    Registerable
{
    uint256 public constant GIF_MAJOR_VERSION = 3;

    bool private _initialized;

    InstanceAdmin internal _instanceAdmin;
    InstanceReader internal _instanceReader;
    BundleManager internal _bundleManager;
    InstanceStore internal _instanceStore;

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert();
        }
        _;
    }

    function initialize(address authority, address registryAddress, address initialOwner) 
        external 
        initializer()
    {
        if(authority == address(0)) {
            revert ErrorInstanceInstanceAdminZero();
        }

        __AccessManaged_init(authority);
        
        IRegistry registry = IRegistry(registryAddress);
        initializeRegisterable(registryAddress, registry.getNftId(), INSTANCE(), true, initialOwner, "");

        registerInterface(type(IInstance).interfaceId);    
    }

    //--- Roles ------------------------------------------------------------//

    function createRole(string memory roleName, string memory adminName)
        external
        restricted // INSTANCE_OWNER_ROLE
        returns (RoleId roleId, RoleId admin)
    {
        (roleId, admin) = _instanceAdmin.createRole(roleName, adminName);
    }

    function grantRole(RoleId roleId, address account) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        AccessManagerExtendedInitializeable(authority()).grantRole(roleId.toInt(), account, 0);
    }

    function revokeRole(RoleId roleId, address account) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        AccessManagerExtendedInitializeable(authority()).revokeRole(roleId.toInt(), account);
    }

    //--- Targets ------------------------------------------------------------//

    function createTarget(address target, string memory name) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _instanceAdmin.createTarget(target, name);
    }

    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _instanceAdmin.setTargetFunctionRoleByInstance(targetName, selectors, roleId);
    }

    function setTargetLocked(address target, bool locked)
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _instanceAdmin.setTargetLockedByInstance(target, locked);
    }

    //--- ITransferInterceptor ------------------------------------------------------------//
    // TODO interception of child components nfts
    function nftMint(address to, uint256 tokenId) external onlyChainNft {
        _instanceAdmin.transferInstanceOwnerRole(address(0), to);
    }

    function nftTransferFrom(address from, address to, uint256 tokenId) external onlyChainNft {
        _instanceAdmin.transferInstanceOwnerRole(from, to);
    }

    //function nftBurn(address from, uint256 tokenId) external onlyChainNft {
        //_instanceAdmin.transferInstanceOwnerRole(from, address(0));
    //}

    //--- initial setup functions -------------------------------------------//

    function setInstanceAdmin(InstanceAdmin accessManager) external restricted {
        if(address(_instanceAdmin) != address(0)) {
            revert ErrorInstanceInstanceAdminAlreadySet(address(_instanceAdmin));
        }
        if(accessManager.authority() != authority()) {
            revert ErrorInstanceInstanceAdminAuthorityMismatch(authority());
        }
        _instanceAdmin = accessManager;      
    }
    
    function setBundleManager(BundleManager bundleManager) external restricted() {
        if(address(_bundleManager) != address(0)) {
            revert ErrorInstanceBundleManagerAlreadySet(address(_bundleManager));
        }
        if(bundleManager.getInstance() != Instance(this)) {
            revert ErrorInstanceBundleManagerInstanceMismatch(address(this));
        }
        if(bundleManager.authority() != authority()) {
            revert ErrorInstanceBundleManagerAuthorityMismatch(authority());
        }
        _bundleManager = bundleManager;
    }

    function setInstanceReader(InstanceReader instanceReader) external restricted() {
        if(instanceReader.getInstance() != Instance(this)) {
            revert ErrorInstanceInstanceReaderInstanceMismatch(address(this));
        }

        _instanceReader = instanceReader;
    }

    //--- external view functions -------------------------------------------//

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }

    function getBundleManager() external view returns (BundleManager) {
        return _bundleManager;
    }

    function getInstanceAdmin() external view returns (InstanceAdmin) {
        return _instanceAdmin;
    }

    function getInstanceAccessManager() external view returns (AccessManagerExtendedInitializeable) {
        return AccessManagerExtendedInitializeable(authority());
    }

    function setInstanceStore(InstanceStore instanceStore) external restricted {
        if(address(_instanceStore) != address(0)) {
            revert ErrorInstanceInstanceStoreAlreadySet(address(_instanceStore));
        }
        if(instanceStore.authority() != authority()) {
            revert ErrorInstanceInstanceStoreAuthorityMismatch(authority());
        }
        _instanceStore = instanceStore;
    }

    function getInstanceStore() external view returns (InstanceStore) {
        return _instanceStore;
    }

    function getMajorVersion() external pure returns (VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(GIF_MAJOR_VERSION);
    }

    function getDistributionService() external view returns (IDistributionService) {
        return IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), VersionPart.wrap(3)));
    }

    function getProductService() external view returns (IProductService) {
        return IProductService(getRegistry().getServiceAddress(PRODUCT(), VersionPart.wrap(3)));
    }

    function getPoolService() external view returns (IPoolService) {
        return IPoolService(getRegistry().getServiceAddress(POOL(), VersionPart.wrap(3)));
    }

    function getPolicyService() external view returns (IPolicyService) {
        return IPolicyService(getRegistry().getServiceAddress(POLICY(), VersionPart.wrap(3)));
    }

    function getBundleService() external view returns (IBundleService) {
        return IBundleService(getRegistry().getServiceAddress(BUNDLE(), VersionPart.wrap(3)));
    }

    //--- internal view/pure functions --------------------------------------//
}