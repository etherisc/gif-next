// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {UFixed} from "../types/UFixed.sol";
import {IBaseComponent} from "./IBaseComponent.sol";

interface IPoolComponent is IBaseComponent {

    event LogUnderwrittenByPool(NftId policyNftId, uint256 collateralizationAmount, address pool);

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    /**
     * @dev creates a new bundle for this pool.
     */
    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        uint256 lifetime,
        bytes memory filter
    ) external returns(NftId bundleNftId);

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

    function isVerifying() external view returns (bool verifying);

    function getCollateralizationLevel() external view returns (UFixed collateralizationLevel);

    function getFees() external view returns (Fee memory poolFee, Fee memory stakingFee, Fee memory performanceFee);

}
