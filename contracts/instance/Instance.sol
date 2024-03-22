// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {NftId} from "../types/NftId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT, DISTRIBUTOR, DISTRIBUTOR_TYPE} from "../types/ObjectType.sol";
import {RoleId, RoleIdLib, eqRoleId, ADMIN_ROLE, INSTANCE_ROLE, INSTANCE_OWNER_ROLE} from "../types/RoleId.sol";
import {VersionPart, VersionPartLib} from "../types/Version.sol";

import {ERC165} from "../shared/ERC165.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceStore} from "./InstanceStore.sol";

import {KeyValueStore} from "./base/KeyValueStore.sol";

import {IAccess} from "./module/IAccess.sol";
import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";

import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IBundleService} from "./service/IBundleService.sol";

contract Instance is
    IInstance,
    AccessManagedUpgradeable,
    Registerable
{
    uint256 public constant GIF_MAJOR_VERSION = 3;

    bool private _initialized;

    InstanceAccessManager internal _accessManager;
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
        (roleId, admin) = _accessManager.createRole(roleName, adminName);
    }

    function grantRole(RoleId roleId, address account) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _accessManager.grantRole(roleId, account);
    }

    function revokeRole(RoleId roleId, address account) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _accessManager.revokeRole(roleId, account);
    }

    //--- Targets ------------------------------------------------------------//

    function createTarget(address target, string memory name) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _accessManager.createTarget(target, name);
    }

    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _accessManager.setTargetFunctionRole(targetName, selectors, roleId);
    }

    function setTargetLocked(string memory targetName, bool locked)
        external 
        restricted // INSTANCE_OWNER_ROLE
    {
        _accessManager.setTargetLockedByInstance(targetName, locked);
    }

    //--- ITransferInterceptor ------------------------------------------------------------//
    function nftMint(address to, uint256 tokenId) external onlyChainNft {
        assert(_accessManager.roleMembers(INSTANCE_OWNER_ROLE()) == 0);// temp
        assert(_accessManager.grantRole(INSTANCE_OWNER_ROLE(), to) == true);
    }

    function nftTransferFrom(address from, address to, uint256 tokenId) external onlyChainNft {
        assert(_accessManager.revokeRole(INSTANCE_OWNER_ROLE(), from) == true);
        assert(_accessManager.grantRole(INSTANCE_OWNER_ROLE(), to) == true);
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

    function setInstanceReader(InstanceReader instanceReader) external restricted() {
        require(instanceReader.getInstance() == Instance(this), "InstanceReader instance mismatch");
        _instanceReader = instanceReader;
    }

    function getMajorVersion() external pure returns (VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(GIF_MAJOR_VERSION);
    }

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }
    
    function setBundleManager(BundleManager bundleManager) external restricted() {
        require(address(_bundleManager) == address(0), "BundleManager is set");
        require(bundleManager.getInstance() == Instance(this), "BundleManager instance mismatch");
        require(bundleManager.authority() == authority(), "BundleManager authority mismatch");
        _bundleManager = bundleManager;
    }

    function getBundleManager() external view returns (BundleManager) {
        return _bundleManager;
    }

    function setInstanceAccessManager(InstanceAccessManager accessManager) external restricted {
        require(address(_accessManager) == address(0), "InstanceAccessManager is set");
        require(accessManager.authority() == authority(), "InstanceAccessManager authority mismatch");  
        _accessManager = accessManager;      
    }

    function getInstanceAccessManager() external view returns (InstanceAccessManager) {
        return _accessManager;
    }

    function setInstanceStore(InstanceStore instanceStore) external restricted {
        require(address(_instanceStore) == address(0), "InstanceStore is set");
        require(instanceStore.authority() == authority(), "InstanceStore authority mismatch");  
        _instanceStore = instanceStore;
    }

    function getInstanceStore() external view returns (InstanceStore) {
        return _instanceStore;
    }

    //--- internal view/pure functions --------------------------------------//
}