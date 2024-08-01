// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {Amount} from "../type/Amount.sol";
import {BundleSet} from "./BundleSet.sol";
import {RiskSet} from "./RiskSet.sol";
import {InstanceAdmin} from "./InstanceAdmin.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {InstanceStore} from "./InstanceStore.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";


interface IInstance is 
    IRegisterable, 
    ITransferInterceptor, 
    IAccessManaged
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

    function createRole(string memory roleName, string memory adminName) external returns (RoleId roleId, RoleId admin);
    function grantRole(RoleId roleId, address account) external;
    function revokeRole(RoleId roleId, address account) external;

    function createTarget(address target, string memory name) external;
    function setTargetFunctionRole(string memory targetName, bytes4[] calldata selectors, RoleId roleId) external;
    function setTargetLocked(address target, bool locked) external;

    function setStakingLockingPeriod(Seconds stakeLockingPeriod) external;
    function setStakingRewardRate(UFixed rewardRate) external;
    function refillStakingRewardReserves(Amount dipAmount) external;

    /// @dev Defunds the staking reward reserves for the specified target.
    /// Permissioned: only the target owner may call this function.
    function withdrawStakingRewardReserves(Amount dipAmount) external returns (Amount newBalance);

    // get instance release and supporting contracts
    function getMajorVersion() external pure returns (VersionPart majorVersion);
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleSet() external view returns (BundleSet);
    function getRiskSet() external view returns (RiskSet);
    function getInstanceAdmin() external view returns (InstanceAdmin);
    function getInstanceStore() external view returns (InstanceStore);
}