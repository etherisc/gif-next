// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../../types/Fee.sol";
import {NftId} from "../../types/NftId.sol";
import {IService} from "../../shared/IService.sol";
import {IBundle} from "../module/IBundle.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {RoleId} from "../../types/RoleId.sol";
import {StateId} from "../../types/StateId.sol";

interface IPoolService is IService {

    event LogPoolServiceMaxCapitalAmountUpdated(NftId poolNftId, uint256 previousMaxCapitalAmount, uint256 currentMaxCapitalAmount);
    event LogPoolServiceBundleOwnerRoleSet(NftId poolNftId, RoleId bundleOwnerRole);

    error ErrorPoolServiceBundleOwnerRoleAlreadySet(NftId poolNftId);

    /// @dev registers a new pool with the registry service
    function register(address poolAddress) external returns(NftId);

    /// @dev defines the required role for bundle owners for the calling pool
    /// default implementation returns PUBLIC ROLE
    function setBundleOwnerRole(RoleId bundleOwnerRole) external;

    /// @dev sets the max capital amount for the calling pool
    function setMaxCapitalAmount(uint256 maxCapitalAmount) external;

    /// @dev set pool sepecific fees
    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;
}
