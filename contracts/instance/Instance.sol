// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "./IInstance.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstanceService} from "./IInstanceService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
import {COMPONENT, INSTANCE} from "../type/ObjectType.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";

contract Instance is
    IInstance,
    Registerable
{
    bool private _initialized;

    IComponentService internal _componentService;
    IInstanceService internal _instanceService;

    InstanceAdmin internal _instanceAdmin;
    InstanceReader internal _instanceReader;
    BundleSet internal _bundleSet;
    RiskSet internal _riskSet;
    InstanceStore internal _instanceStore;
    NftId [] internal _products;
    bool internal _tokenRegistryDisabled;


    modifier onlyCustomRoleAdmin(RoleId roleId) {
        if (!_instanceAdmin.isRoleCustom(roleId)) {
            revert ErrorInstanceNotCustomRole(roleId);
        }

        // instance owner can always act as role admin
        address account = msg.sender;
        if (account != getOwner()) {
            if (!_instanceAdmin.isRoleAdmin(roleId, account)) {
                revert ErrorInstanceNotRoleAdmin(roleId, account);
            }
        }
        _;
    }


    function initialize(
        InstanceAdmin instanceAdmin, 
        InstanceStore instanceStore,
        BundleSet bundleSet,
        RiskSet riskSet,
        InstanceReader instanceReader,
        IRegistry registry, 
        VersionPart release,
        address initialOwner,
        bool tokenRegistryDisabled
    ) 
        external 
        initializer()
    {
        if(address(instanceAdmin) == address(0)) {
            revert ErrorInstanceInstanceAdminZero();
        }

        _instanceAdmin = instanceAdmin;

        // setup instance object info
        __Registerable_init({
            authority: instanceAdmin.authority(),
            registry: address(registry), 
            parentNftId: registry.getNftId(), 
            objectType: INSTANCE(), 
            isInterceptor: false, 
            initialOwner: initialOwner, 
            data: ""});

        // store instance supporting contracts
        _instanceStore = instanceStore;
        _bundleSet = bundleSet;
        _riskSet = riskSet;
        _instanceReader = instanceReader;

        // initialize instance supporting contracts
        _instanceStore.initialize();
        _bundleSet.initialize(instanceAdmin.authority(), address(registry));
        _riskSet.initialize(instanceAdmin.authority(), address(registry));
        _instanceReader.initialize();

        _componentService = IComponentService(
            getRegistry().getServiceAddress(
                COMPONENT(), 
                release));

        _instanceService = IInstanceService(
            getRegistry().getServiceAddress(
                INSTANCE(), 
                release));

        _tokenRegistryDisabled = tokenRegistryDisabled;

        _registerInterface(type(IInstance).interfaceId);    
    }


    function setInstanceLocked(bool locked)
        external 
        // not restricted(): need to be able to unlock a locked instance
        onlyOwner()
    {
        _instanceService.setInstanceLocked(locked);
    }


    function upgradeInstanceReader()
        external
        restricted()
        onlyOwner()
    {
        _instanceService.upgradeInstanceReader();
    }


    //--- ProductRegistration ----------------------------------------------//

    function registerProduct(address product, address token)
        external
        restricted()
        onlyOwner()
        returns (NftId productNftId)
    {
        productNftId = _componentService.registerProduct(product, token);
        _products.push(productNftId);
    }

    //--- Staking ----------------------------------------------------------//

    function setStakingLockingPeriod(Seconds stakeLockingPeriod)
        external
        restricted()
        onlyOwner()
    {
        _instanceService.setStakingLockingPeriod(stakeLockingPeriod);
    }

    function setStakingRewardRate(UFixed rewardRate)
        external
        restricted()
        onlyOwner()
    {
        _instanceService.setStakingRewardRate(rewardRate);
    }

    function setStakingMaxAmount(Amount maxStakedAmount)
        external
        onlyOwner()
    {
        _instanceService.setStakingMaxAmount(maxStakedAmount);
    }

    function refillStakingRewardReserves(Amount dipAmount)
        external
        restricted()
        onlyOwner()
    {
        address instanceOwner = msg.sender;
        _instanceService.refillStakingRewardReserves(instanceOwner, dipAmount);
    }

    function withdrawStakingRewardReserves(Amount dipAmount)
        external
        restricted()
        onlyOwner()
        returns (Amount newBalance)
    {
        return _instanceService.withdrawStakingRewardReserves(dipAmount);
    }

    //--- Roles ------------------------------------------------------------//

    /// @inheritdoc IInstance
    function createRole(
        string memory roleName, 
        RoleId adminRoleId,
        uint32 maxMemberCount
    )
        external
        restricted()
        onlyOwner()
        returns (RoleId roleId)
    {
        roleId = _instanceService.createRole(roleName, adminRoleId, maxMemberCount);
        emit LogInstanceCustomRoleCreated(roleId, roleName, adminRoleId, maxMemberCount);
    }


    /// @inheritdoc IInstance
    function setRoleActive(RoleId roleId, bool active)
        external 
        restricted()
        onlyCustomRoleAdmin(roleId)
    {
        _instanceService.setRoleActive(roleId, active);
        emit LogInstanceCustomRoleActiveSet(roleId, active, msg.sender);
    }


    /// @inheritdoc IInstance
    function grantRole(RoleId roleId, address account) 
        external 
        restricted()
        onlyCustomRoleAdmin(roleId)
    {
        _instanceService.grantRole(roleId, account);
        emit LogInstanceCustomRoleGranted(roleId, account, msg.sender);
    }


    /// @inheritdoc IInstance
    function revokeRole(RoleId roleId, address account) 
        external 
        restricted()
        onlyCustomRoleAdmin(roleId)
    {
        _instanceService.revokeRole(roleId, account);
        emit LogInstanceCustomRoleRevoked(roleId, account, msg.sender);
    }

    //--- Targets ------------------------------------------------------------//

    /// @inheritdoc IInstance
    function createTarget(address target, string memory name) 
        external 
        restricted()
        onlyOwner()
        returns (RoleId targetRoleId)
    {
        targetRoleId = _instanceService.createTarget(target, name);
        emit LogInstanceCustomTargetCreated(target, targetRoleId, name);
    }


    /// @inheritdoc IInstance
    function setTargetLocked(address target, bool locked)
        external 
        // not restricted(): instance owner may need to be able to unlock targets on an locked instance
        onlyOwner()
    {
        _instanceService.setTargetLocked(target, locked);
        emit LogInstanceTargetLocked(target, locked);
    }


    function setTargetFunctionRole(
        string memory targetName,
        bytes4[] calldata selectors,
        RoleId roleId
    ) 
        external 
        restricted()
        onlyOwner()
    {
        // TODO refactor
        // _instanceAdmin.setTargetFunctionRoleByInstance(targetName, selectors, roleId);
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

    function isInstanceLocked() external view returns (bool) {
        return _instanceAdmin.isLocked();
    }

    function isTargetLocked(address target) external view returns (bool) {
        return _instanceAdmin.isTargetLocked(target);
    }

    function products() external view returns (uint256 productCount) {
        return _products.length;
    }

    function getProductNftId(uint256 idx) external view returns (NftId productNftId) {
        return _products[idx];
    }

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }

    function getBundleSet() external view returns (BundleSet) {
        return _bundleSet;
    }

    function getRiskSet() external view returns (RiskSet) {
        return _riskSet;
    }

    function getInstanceAdmin() external view returns (InstanceAdmin) {
        return _instanceAdmin;
    }

    function getInstanceStore() external view returns (InstanceStore) {
        return _instanceStore;
    }

    function isTokenRegistryDisabled() external view returns (bool) {
        return _tokenRegistryDisabled;
    }

    //--- internal view/pure functions --------------------------------------//


    function _checkCustomRole(RoleId roleId, bool exists) internal view {
        if (!_instanceAdmin.isRoleCustom(roleId)) {
            revert ErrorInstanceNotCustomRole(roleId);
        }
    }

}