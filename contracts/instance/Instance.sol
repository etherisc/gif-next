// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {COMPONENT, INSTANCE} from "../type/ObjectType.sol";
import {IInstance} from "./IInstance.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

contract Instance is
    IInstance,
    AccessManagedUpgradeable,
    Registerable
{
    bool private _initialized;

    IComponentService internal _componentService;
    IInstanceService internal _instanceService;
    InstanceAdmin internal _instanceAdmin;
    InstanceReader internal _instanceReader;
    BundleSet internal _bundleManager;
    InstanceStore internal _instanceStore;

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert();
        }
        _;
    }

    function initialize(
        InstanceAdmin instanceAdmin, 
        InstanceStore instanceStore,
        BundleSet bundleManager,
        InstanceReader instanceReader,
        IRegistry registry, 
        address initialOwner
    ) 
        external 
        initializer()
    {
        _instanceAdmin = instanceAdmin;
        if(_instanceAdmin.authority() == address(0)) {
            revert ErrorInstanceInstanceAdminZero();
        }

        // set authority to instance admin authority
        __AccessManaged_init(_instanceAdmin.authority());

        // setup instance object info
        _initializeRegisterable(
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

        _componentService = IComponentService(
            getRegistry().getServiceAddress(
                COMPONENT(), 
                getRelease()));

        _instanceService = IInstanceService(
            getRegistry().getServiceAddress(
                INSTANCE(), 
                getRelease()));

        _registerInterface(type(IInstance).interfaceId);    
    }

    //--- ProductRegistration ----------------------------------------------//
    function registerProduct(address product)
        external
        onlyOwner()
        returns (NftId productNftId)
    {
        return _componentService.registerProduct(product);
    }

    //--- Staking ----------------------------------------------------------//

    function setStakingLockingPeriod(Seconds stakeLockingPeriod)
        external
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

    function nftTransferFrom(address from, address to, uint256 tokenId, address operator) external onlyChainNft {
        // TODO refactor
        // _instanceAdmin.transferInstanceOwnerRole(from, to);
    }

    //--- initial setup functions -------------------------------------------//


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

    function getBundleSet() external view returns (BundleSet) {
        return _bundleManager;
    }

    function getInstanceAdmin() external view returns (InstanceAdmin) {
        return _instanceAdmin;
    }

    function getInstanceStore() external view returns (InstanceStore) {
        return _instanceStore;
    }

    //--- internal view/pure functions --------------------------------------//
}