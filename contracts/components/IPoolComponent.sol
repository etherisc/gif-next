// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../types/Fee.sol";
import {IComponent} from "./IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {UFixed} from "../types/UFixed.sol";

interface IPoolComponent is IComponent {

    event LogUnderwrittenByPool(NftId policyNftId, uint256 collateralizationAmount, address pool);

    function getSetupInfo() external view returns (ISetup.PoolSetupInfo memory setupInfo);

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    function setBundleFee(
        NftId policyNftId, 
        Fee memory fee
    ) external;

    /** 
     * @dev this is a callback function that is called by the product service when underwriting a policy.
     * the pool has the option to check the details and object to underwriting by reverting.
     * the function is only called for "active" pools that ask to be involved/notified
     * by product related state changes.
     */
    function underwrite(
        NftId policyNftId, 
        bytes memory policyData,
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    ) external;

    function lockBundle(NftId bundleNftId) external;

    function unlockBundle(NftId bundleNftId) external;

    /**
     * @dev returns true iff the policy application data in policyData matches
     * with the bundle filter criteria encoded in bundleFilter. 
     */
    function policyMatchesBundle(
        bytes memory policyData,
        bytes memory bundleFilter
    )
        external
        view
        returns (bool isMatching);

    function isConfirmingApplication() external view returns (bool isConfirmingApplication);

    function getCollateralizationLevel() external view returns (UFixed collateralizationLevel);

}
