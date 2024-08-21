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
    error ErrorInstanceInstanceAdminAlreadySet(address InstanceAdmin);
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

    /// @dev Register a product with the instance.
    function registerProduct(address product) external returns (NftId productNftId);

    function createRole(string memory roleName, string memory adminName) external returns (RoleId roleId, RoleId admin);
    function grantRole(RoleId roleId, address account) external;
    function revokeRole(RoleId roleId, address account) external;

    function createTarget(address target, string memory name) external;
    function setTargetFunctionRole(string memory targetName, bytes4[] calldata selectors, RoleId roleId) external;
    function setLocked(address target, bool locked) external;

    function setStakingLockingPeriod(Seconds stakeLockingPeriod) external;
    function setStakingRewardRate(UFixed rewardRate) external;
    function refillStakingRewardReserves(Amount dipAmount) external;

    /// @dev Defunds the staking reward reserves for the specified target.
    /// Permissioned: only the target owner may call this function.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    // get products
    function products() external view returns (uint256 productCount);
    function getProductNftid(uint256 idx) external view returns (NftId productNftId);

    // get supporting contracts
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleSet() external view returns (BundleSet);
    function getRiskSet() external view returns (RiskSet);
    function getInstanceAdmin() external view returns (InstanceAdmin);
    function getInstanceStore() external view returns (InstanceStore);
}