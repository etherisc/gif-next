// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {ProductStore} from "./ProductStore.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";


interface IInstance is 
    IRegisterable
{
    // role handling
    event LogInstanceCustomRoleCreated(RoleId roleId, string roleName, RoleId adminRoleId, uint32 maxMemberCount);
    event LogInstanceCustomRoleActiveSet(RoleId roleId, bool active, address caller);
    event LogInstanceCustomRoleGranted(RoleId roleId, address account, address caller);
    event LogInstanceCustomRoleRevoked(RoleId roleId, address account, address caller);

    // target handling
    event LogInstanceCustomTargetCreated(address target, RoleId targetRoleId, string name);
    event LogInstanceTargetLocked(address target, bool locked);
    event LogInstanceCustomTargetFunctionRoleSet(address target, bytes4[] selectors, RoleId roleId);

    // modifier is onlyRoleAdmin
    error ErrorInstanceNotCustomRole(RoleId roleId);
    error ErrorInstanceNotRoleAdmin(RoleId roleId, address account);

    error ErrorInstanceInstanceAdminZero();
    error ErrorInstanceInstanceAdminAlreadySet(address instanceAdmin);
    error ErrorInstanceInstanceAdminAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceBundleSetAlreadySet(address instanceBundleSet);
    error ErrorInstanceBundleSetInstanceMismatch(address instance);
    error ErrorInstanceBundleSetAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceRiskSetAlreadySet(address instanceRiskSet);
    error ErrorInstanceRiskSetInstanceMismatch(address instance);
    error ErrorInstanceRiskSetAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceInstanceReaderInstanceMismatch(address instanceAuthority);

    error ErrorInstanceInstanceStoreAlreadySet(address instanceStore);
    error ErrorInstanceInstanceStoreAuthorityMismatch(address instanceAuthority);

    struct InstanceContracts {
        InstanceAdmin instanceAdmin;
        InstanceStore instanceStore;
        ProductStore productStore;
        BundleSet bundleSet;
        RiskSet riskSet;
        InstanceReader instanceReader;
    }

    struct InstanceInfo {
        uint64 requestsCount;
    }

    ///--- instance ---------------------------------------------------------//

    /// @dev Locks/unlocks the complete instance, including all its components.
    function setInstanceLocked(bool locked) external;

    /// @dev Upgrades the instance reader to the specified target.
    function upgradeInstanceReader() external;

    /// @dev Sets the instance reader for the instance.
    /// Permissioned: only the instance service may call this function.
    function setInstanceReader(InstanceReader instanceReader) external;

    ///--- staking ----------------------------------------------------------//

    /// @dev Sets the duration for locking new stakes on this instance..
    function setStakingLockingPeriod(Seconds stakeLockingPeriod) external;

    /// @dev Sets the staking reward rate [apr] for this instance.
    function setStakingRewardRate(UFixed rewardRate) external;

    /// @dev Sets the maximum staked amount for this instance.
    function setStakingMaxAmount(Amount maxStakedAmount) external;

    /// @dev Refills the staking reward reserves for the specified target.
    function refillStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    /// @dev Defunds the staking reward reserves for the specified target.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    ///--- product/component ------------------------------------------------//

    /// @dev Locks/unlocks the specified target.
    function setTargetLocked(address target, bool locked) external;

    /// @dev Register a product with the instance.
    function registerProduct(address product, address token) external returns (NftId productNftId);

    ///--- authz ------------------------------------------------------------//

    /// @dev Creates a new custom role for the calling instance.
    /// Custom roles are intended to be used for access control of custom components and its helper contracts.
    /// Custom roles are not intended to be used as target roles for custom contracts.
    function createRole(string memory roleName, RoleId adminRoleId, uint32 maxMemberCount) external returns (RoleId roleId);

    /// @dev Activates/deactivates the specified role.
    /// Only instance owner or account with role admin role can call this function.
    function setRoleActive(RoleId roleId, bool active) external;

    /// @dev Grants the specified role to the account.
    /// Only active roles can be granted.
    /// Only instance owner or account with role admin role can call this function.
    function grantRole(RoleId roleId, address account) external;

    /// @dev Revokes the specified role from the account.
    /// Only instance owner or account with role admin role can call this function.
    function revokeRole(RoleId roleId, address account) external;

    /// @dev Creates a new custom target.
    /// Custom targets are intended to be used for access control helper contracts of components.
    /// Custom targets are not intended to be used for components.
    function createTarget(address target, string memory name) external returns (RoleId contractRoleId);

    /// @dev Authorizes the specified functions for the target and provided role.
    function authorizeFunctions(address target, RoleId roleId, IAccess.FunctionInfo[] memory functions) external;

    /// @dev Removes any role authorization for the specified functions.
    function unauthorizeFunctions(address target, IAccess.FunctionInfo[] memory functions) external;

    //--- getters -----------------------------------------------------------//

    /// @dev returns the overall locking state of the instance (including all components)
    function isInstanceLocked() external view returns (bool isLocked);

    /// @dev returns the locking state of the specified target
    function isTargetLocked(address target) external view returns (bool isLocked);

    // get products
    function products() external view returns (uint256 productCount);
    function getProductNftId(uint256 idx) external view returns (NftId productNftId);

    // get supporting contracts
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleSet() external view returns (BundleSet);
    function getRiskSet() external view returns (RiskSet);
    function getInstanceAdmin() external view returns (InstanceAdmin);
    function getInstanceStore() external view returns (InstanceStore);
    function getProductStore() external view returns (ProductStore);
    function isTokenRegistryDisabled() external view returns (bool);
}