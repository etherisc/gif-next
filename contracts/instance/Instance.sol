// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Amount} from "../type/Amount.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {RiskId} from "../type/RiskId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT, DISTRIBUTOR, DISTRIBUTOR_TYPE} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ReferralId} from "../type/Referral.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IInstance} from "./IInstance.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
// TODO cleanup
// import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceAdminNew} from "./InstanceAdminNew.sol";
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

    IInstanceService internal _instanceService;
    InstanceAdminNew internal _instanceAdmin;
    InstanceReader internal _instanceReader;
    BundleManager internal _bundleManager;
    InstanceStore internal _instanceStore;

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert();
        }
        _;
    }

    function initialize(
        InstanceAdminNew instanceAdmin, 
        InstanceStore instanceStore,
        BundleManager bundleManager,
        InstanceReader instanceReader,
        IRegistry registry, 
        address initialOwner
    ) 
        external 
        initializer()
    {
        _instanceAdmin = instanceAdmin;
        if(_instanceAdmin.authority() == address(0)) {
            // TODO rename error
            revert ErrorInstanceInstanceAdminZero();
        }

        // set authority to instance admin authority
        __AccessManaged_init(_instanceAdmin.authority());

        // setup instance object info
        initializeRegisterable(
            address(registry), 
            registry.getNftId(), 
            INSTANCE(), 
            true, 
            initialOwner, 
            "");

        // store instance supporting contracts
        _instanceStore = instanceStore;
        _bundleManager = bundleManager;
        _instanceReader = instanceReader;

        // initialize instance supporting contracts
        _instanceStore.initialize();
        _bundleManager.initialize();
        _instanceReader.initialize();

        _instanceService = IInstanceService(
            getRegistry().getServiceAddress(
                INSTANCE(), 
                getMajorVersion()));

        registerInterface(type(IInstance).interfaceId);    
    }

    //--- Staking ----------------------------------------------------------//

    function setStakingLockingPeriod(Seconds stakeLockingPeriod)
        external
        // TODO decide if onlyOwner or restricted to instance owner role is better
        onlyOwner()
    {
        _instanceService.setStakingLockingPeriod(stakeLockingPeriod);
    }

    function setStakingRewardRate(UFixed rewardRate)
        external
        onlyOwner()
    {
        _instanceService.setStakingRewardRate(rewardRate);
    }

    function refillStakingRewardReserves(Amount dipAmount)
        external
        onlyOwner()
    {
        address instanceOwner = msg.sender;
        _instanceService.refillStakingRewardReserves(instanceOwner, dipAmount);
    }

    function withdrawStakingRewardReserves(Amount dipAmount)
        external
        onlyOwner()
        returns (Amount newBalance)
    {
        return _instanceService.withdrawStakingRewardReserves(dipAmount);
    }

    //--- Roles ------------------------------------------------------------//

    function createRole(string memory roleName, string memory adminName)
        external
        onlyOwner()
        returns (RoleId roleId, RoleId admin)
    {
        // TODO refactor
        // (roleId, admin) = _instanceAdmin.createRole(roleName, adminName);
    }

    function grantRole(RoleId roleId, address account) 
        external 
        onlyOwner()
    {
        _instanceAdmin.grantRole(roleId, account);
    }

    function revokeRole(RoleId roleId, address account) 
        external 
        onlyOwner()
    {
        // TODO refactor
        // AccessManagerExtendedInitializeable(authority()).revokeRole(roleId.toInt(), account);
    }

    //--- Targets ------------------------------------------------------------//

    function createTarget(address target, string memory name) 
        external 
        onlyOwner()
    {
        // TODO refactor
        // _instanceAdmin.createTarget(target, name);
    }

    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        external 
        onlyOwner()
    {
        // TODO refactor
        // _instanceAdmin.setTargetFunctionRoleByInstance(targetName, selectors, roleId);
    }

    function setTargetLocked(address target, bool locked)
        external 
        onlyOwner()
    {
        // TODO refactor
        // _instanceAdmin.setTargetLockedByInstance(target, locked);
    }

    //--- ITransferInterceptor ----------------------------------------------//

    // TODO interception of child components nfts
    function nftMint(address to, uint256 tokenId) external onlyChainNft {
        // TODO refactor
        // _instanceAdmin.transferInstanceOwnerRole(address(0), to);
    }

    function nftTransferFrom(address from, address to, uint256 tokenId) external onlyChainNft {
        // TODO refactor
        // _instanceAdmin.transferInstanceOwnerRole(from, to);
    }

    //function nftBurn(address from, uint256 tokenId) external onlyChainNft {
        //_instanceAdmin.transferInstanceOwnerRole(from, address(0));
    //}

    //--- initial setup functions -------------------------------------------//

    // TODO cleanup
    // function setInstanceAdmin(InstanceAdmin accessManager) external restricted {
    //     if(address(_instanceAdmin) != address(0)) {
    //         revert ErrorInstanceInstanceAdminAlreadySet(address(_instanceAdmin));
    //     }
    //     if(accessManager.authority() != authority()) {
    //         revert ErrorInstanceInstanceAdminAuthorityMismatch(authority());
    //     }
    //     _instanceAdmin = accessManager;      
    // }

    // function setBundleManager(BundleManager bundleManager) external restricted() {
    //     if(address(_bundleManager) != address(0)) {
    //         revert ErrorInstanceBundleManagerAlreadySet(address(_bundleManager));
    //     }
    //     if(bundleManager.getInstance() != Instance(this)) {
    //         revert ErrorInstanceBundleManagerInstanceMismatch(address(this));
    //     }
    //     if(bundleManager.authority() != authority()) {
    //         revert ErrorInstanceBundleManagerAuthorityMismatch(authority());
    //     }
    //     _bundleManager = bundleManager;
    // }

    // function setInstanceStore(InstanceStore instanceStore) external restricted {
    //     if(address(_instanceStore) != address(0)) {
    //         revert ErrorInstanceInstanceStoreAlreadySet(address(_instanceStore));
    //     }
    //     if(instanceStore.authority() != authority()) {
    //         revert ErrorInstanceInstanceStoreAuthorityMismatch(authority());
    //     }
    //     _instanceStore = instanceStore;
    // }

    function setInstanceReader(InstanceReader instanceReader)
        external
        restricted()
    {
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

    function getInstanceAdmin() external view returns (InstanceAdminNew) {
        return _instanceAdmin;
    }

    function getInstanceStore() external view returns (InstanceStore) {
        return _instanceStore;
    }

    function getMajorVersion() public pure returns (VersionPart majorVersion) {
        return VersionPartLib.toVersionPart(GIF_MAJOR_VERSION);
    }

    //--- internal view/pure functions --------------------------------------//
}