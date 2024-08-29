// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";


interface IInstance is 
    IRegisterable
{
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
    function refillStakingRewardReserves(Amount dipAmount) external;

    /// @dev Defunds the staking reward reserves for the specified target.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    ///--- product/component ------------------------------------------------//

    /// @dev Locks/unlocks the specified target.
    function setTargetLocked(address target, bool locked) external;

    /// @dev Register a product with the instance.
    function registerProduct(address product, address token) external returns (NftId productNftId);

    ///--- authz ------------------------------------------------------------//

    function createRole(string memory roleName, string memory adminName) external returns (RoleId roleId, RoleId admin);
    function grantRole(RoleId roleId, address account) external;
    function revokeRole(RoleId roleId, address account) external;

    function createTarget(address target, string memory name) external;
    function setTargetFunctionRole(string memory targetName, bytes4[] calldata selectors, RoleId roleId) external;

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
    function isTokenRegistryDisabled() external view returns (bool);
}