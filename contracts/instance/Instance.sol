// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
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

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert();
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
        address initialOwner
    ) 
        external 
        initializer()
    {
        if(address(instanceAdmin) == address(0)) {
            revert ErrorInstanceInstanceAdminZero();
        }

        _instanceAdmin = instanceAdmin;

        // setup instance object info
        __Registerable_init(
            instanceAdmin.authority(),
            address(registry), 
            registry.getNftId(), 
            INSTANCE(), 
            true, 
            initialOwner, 
            "");

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
        productNftId = _componentService.registerProduct(product);
        _products.push(productNftId);
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

    function setLocked(address target, bool locked)
        external 
        onlyOwner()
    {
        _componentService.setLockedFromInstance(target, locked);
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

    function products() external view returns (uint256 productCount) {
        return _products.length;
    }

    function getProductNftid(uint256 idx) external view returns (NftId productNftId) {
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

    //--- internal view/pure functions --------------------------------------//
}