// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
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
import {ProductStore} from "./ProductStore.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";

contract Instance is
    IInstance,
    Registerable
{
    IComponentService internal _componentService;
    IInstanceService internal _instanceService;

    InstanceAdmin internal _instanceAdmin;
    InstanceReader internal _instanceReader;
    BundleSet internal _bundleSet;
    RiskSet internal _riskSet;
    InstanceStore internal _instanceStore;
    ProductStore internal _productStore;
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
        InstanceContracts memory instanceContracts,
        IRegistry registry, 
        address initialOwner,
        bool tokenRegistryDisabled // only disable for testing
    ) 
        external 
        initializer()
    {
        if(address(instanceContracts.instanceAdmin) == address(0)) {
            revert ErrorInstanceInstanceAdminZero();
        }

        _instanceAdmin = instanceContracts.instanceAdmin;

        // setup instance object info
        __Registerable_init({
            authority: instanceContracts.instanceAdmin.authority(),
            registry: address(registry), 
            parentNftId: registry.getNftId(), 
            objectType: INSTANCE(), 
            isInterceptor: false, 
            initialOwner: initialOwner, 
            data: ""});

        // store instance supporting contracts
        _instanceStore = instanceContracts.instanceStore;
        _productStore = instanceContracts.productStore;
        _bundleSet = instanceContracts.bundleSet;
        _riskSet = instanceContracts.riskSet;
        _instanceReader = instanceContracts.instanceReader;

        // initialize instance supporting contracts
        _instanceStore.initialize();
        _productStore.initialize();
        _bundleSet.initialize(instanceContracts.instanceAdmin.authority(), address(registry));
        _riskSet.initialize(instanceContracts.instanceAdmin.authority(), address(registry));
        _instanceReader.initialize();

        _componentService = IComponentService(
            getRegistry().getServiceAddress(
                COMPONENT(), 
                getRelease()));

        _instanceService = IInstanceService(
            getRegistry().getServiceAddress(
                INSTANCE(), 
                getRelease()));

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
        restricted()
        onlyOwner()
    {
        _instanceService.setStakingMaxAmount(maxStakedAmount);
    }

    function refillStakingRewardReserves(Amount dipAmount)
        external
        restricted()
        onlyOwner()
        returns (Amount newRewardReserveBalance)
    {
        address instanceOwner = msg.sender;
        return _instanceService.refillInstanceRewardReserves(instanceOwner, dipAmount);
    }

    function withdrawStakingRewardReserves(Amount dipAmount)
        external
        restricted()
        onlyOwner()
        returns (Amount newRewardReserveBalance)
    {
        return _instanceService.withdrawInstanceRewardReserves(dipAmount);
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


    /// @inheritdoc IInstance
    function authorizeFunctions(
        address target, 
        RoleId roleId, 
        IAccess.FunctionInfo[] memory functions
    )
        external 
        restricted()
        onlyOwner()
    {
        _instanceService.authorizeFunctions(target, roleId, functions);
    }


    /// @inheritdoc IInstance
    function unauthorizeFunctions(
        address target, 
        IAccess.FunctionInfo[] memory functions
    )
        external 
        restricted()
        onlyOwner()
    {
        _instanceService.unauthorizeFunctions(target, functions);
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

    function getProduct(uint256 idx) external view returns (NftId productNftId) {
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

    function getProductStore() external view returns (ProductStore) {
        return _productStore;
    }

    function isTokenRegistryDisabled() external view returns (bool) {
        return _tokenRegistryDisabled;
    }
}