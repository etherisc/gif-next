// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../types/Fee.sol";
import {IComponent} from "./IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {UFixed} from "../types/UFixed.sol";

/// @dev pool components hold and manage the collateral to cover active policies
/// pools come in different flavors
interface IPoolComponent is IComponent {

    event LogUnderwrittenByPool(NftId policyNftId, uint256 collateralizationAmount, address pool);

    error ErrorPoolNotPoolService(address service);

    function getSetupInfo() external view returns (ISetup.PoolSetupInfo memory setupInfo);

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    /// @dev sets an additional bundle fee, this fee is added on top of the poolFee and deducted from the premium amounts.
    /// via these fees individual bundler owner may earn income per policy in the context of peer to peer pools
    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    ) external;

    /// @dev this is a callback function that is called by the product service when underwriting a policy.
    /// the pool has the option to check the details and object to underwriting by reverting.
    /// the function is only called for "active" pools that ask to be involved/notified
    /// by product related state changes.
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory policyData,
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    ) external;

    function lockBundle(NftId bundleNftId) external;

    function unlockBundle(NftId bundleNftId) external;

    /// @dev defines the multiplier to calculate the required collateral to cover a given sum insured amount
    function getCollateralizationLevel() external view returns (UFixed collateralizationLevel);

    /// @dev declares if pool intercept transfers of bundle nft ids
    /// - yes: pool may block transfer of bundle ownership or simply updates some bookkeeping related to bundle ownership. callback function is nftTransferFrom
    /// - no: pool is not involved in transfer of bundle ownership
    function isInterceptingBundleTransfers() external view returns (bool);

    /// @dev declares if pool relies on external management of collateral (yes/no): 
    /// - yes: underwriting of new policies does not require an actual token balance, instead it is assumed that the pool owner will manage funds externally and inject enough tokens to allow process confirmed payouts
    /// - no: the pool smart contract ensures that the necessary capacity of the pool prior to underwriting.
    function isExternallyManaged() external view returns (bool);

    /// @dev declares if pool component is actively involved in underwriting (yes/no): 
    /// - yes: verifying pools components actively confirm underwriting applications, ie the pool component logic explicitly needs to confirm the locking of collateral to cover the sum insured of the policy
    /// - no: underwriting a policy does not require any interaction with the pool component if the covering bundle can provide the necessary captial
    function isVerifyingApplications() external view returns (bool);

    /// @dev returns true iff the policy application data in policyData matches
    /// with the bundle filter criteria encoded in bundleFilter
    /// this is a callback function that is only called if a pool declares itself as a verifying pool
    function policyMatchesBundle(
        bytes memory policyData,
        bytes memory bundleFilter
    )
        external
        view
        returns (bool isMatching);

}
