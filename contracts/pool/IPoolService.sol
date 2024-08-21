// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {UFixed} from "../type/UFixed.sol";

interface IPoolService is IService {

    event LogPoolServiceMaxBalanceAmountUpdated(NftId poolNftId, Amount previousMaxCapitalAmount, Amount currentMaxCapitalAmount);
    event LogPoolServiceWalletFunded(NftId poolNftId, address poolOwner, Amount amount);
    event LogPoolServiceWalletDefunded(NftId poolNftId, address poolOwner, Amount amount);

    event LogPoolServiceBundleCreated(NftId instanceNftId, NftId poolNftId, NftId bundleNftId);
    event LogPoolServiceBundleClosed(NftId instanceNftId, NftId poolNftId, NftId bundleNftId);

    event LogPoolServiceBundleStaked(NftId instanceNftId, NftId poolNftId, NftId bundleNftId, Amount amount, Amount netAmount);
    event LogPoolServiceBundleUnstaked(NftId instanceNftId, NftId poolNftId, NftId bundleNftId, Amount amount, Amount netAmount);

    event LogPoolServiceFeesWithdrawn(NftId bundleNftId, address recipient, address tokenAddress, Amount amount);

    event LogPoolServiceProcessFundedClaim(NftId policyNftId, ClaimId claimId, Amount availableAmount);

    error ErrorPoolServicePoolNotExternallyManaged(NftId poolNftId);
    error ErrorPoolServicePolicyPoolMismatch(NftId policyNftId, NftId productNftId, NftId expectedProductNftId);
    error ErrorPoolServiceBundleOwnerRoleAlreadySet(NftId poolNftId);
    error ErrorPoolServiceInvalidTransferAmount(Amount expectedAmount, Amount actualAmount);
    error ErrorPoolServiceBundlePoolMismatch(NftId bundleNftId, NftId poolNftId);
    error ErrorPoolServiceMaxBalanceAmountExceeded(NftId poolNftId, Amount maxBalanceAmount, Amount currentBalanceAmount, Amount transferAmount);
    error ErrorPoolServiceFeesWithdrawAmountExceedsLimit(Amount amount, Amount limit);

    /// @dev sets the max balance amount for the calling pool
    function setMaxBalanceAmount(Amount maxBalanceAmount) external;

    /// @dev locks required collateral to cover the specified application (and turn it into a policy)
    /// - retention level == 1: the full collateral amount will be locked by the specified bundle
    /// - retention level < 1: a part of the coverage is provided by the specified bundle, the rest by the pool component
    /// in which case the pool component might hold a re-insurance policy
    /// may only be called by the policy service for unlocked pool components
    function lockCollateral(
        IInstance instance, 
        address token,
        NftId productNftId,
        NftId applicationNftId,
        NftId bundleNftId,
        Amount sumInsuredAmount // premium amount after product and distribution fees
    )
        external
        returns (
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        );


    /// @dev releases the remaining collateral linked to the specified policy
    /// may only be called by the policy service for unlocked pool components
    function releaseCollateral(
        IInstance instance, 
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo
    ) external;


    /// @dev reduces the locked collateral in the bundle associated with the specified policy and updates pool/bundle counters
    /// every payout of a policy reduces the collateral by the payout amount
    /// may only be called by the claim service for unlocked pool components
    function processPayout(
        InstanceReader instanceReader,
        InstanceStore instanceStore, 
        NftId productNftId,
        NftId policyNftId, 
        NftId bundleNftId,
        PayoutId payoutId,
        Amount payoutAmount,
        address payoutBeneficiary
    ) external;


    /// @dev increase stakes for bundle
    /// staking fees will be deducted by the pool service from the staking amount
    /// may only be called by registered and unlocked pool components
    function stake(NftId bundleNftId, Amount amount) external returns(Amount netAmount);


    /// @dev decrease stakes for bundle
    /// performance fees will be deducted by the pool service from the staking amount
    /// may only be called by registered and unlocked pool components
    function unstake(NftId bundleNftId, Amount amount) external returns(Amount netAmount);


    /// @dev closes the specified bundle
    /// only open bundles (active or locked) may be closed
    /// to close a bundle it may not have any non-closed polices attached to it
    /// bundle fees and remaining capital (after deduction of the performance fee) will be transferred to the bundle owner
    /// may only be called by registered and unlocked pool components
    function closeBundle(NftId bundleNftId) external;


    /// @dev Withdraw bundle feeds for the specified bundle.
    function withdrawBundleFees(NftId bundleNftId, Amount amount) external returns (Amount withdrawnAmount);


    /// @dev Informs product about available funds to process a confirmed claim.
    /// The function triggers a callback to the product component when the product's property isProcessingFundedClaims is set.
    function processFundedClaim(NftId policyNftId, ClaimId claimId, Amount availableAmount) external;


    /// @dev Fund the pool wallet with the provided amount.
    /// This function will collect the amount from the pool owner and transfers it to the pool wallet.
    /// The function will not update balance amounts managed by the framework.
    /// Only available for externally managed pools.
    function fundPoolWallet(Amount amount) external;


    /// @dev Defund the specified pool wallet with the provided amount.
    /// This function will transfer the amount from the pool wallet to the pool owner.
    /// The function will not update balance amounts managed by the framework.
    /// Only available for externally managed pools.
    function defundPoolWallet(Amount amount) external;


    /// @dev processes the sale of a bundle and track the pool fee and bundle fee amounts
    function processSale(NftId bundleNftId, IPolicy.PremiumInfo memory premium) external;


    // /// @dev Calulate required collateral for the provided parameters.
    // function calculateRequiredCollateral(
    //     InstanceReader instanceReader,
    //     NftId productNftId, 
    //     Amount sumInsuredAmount
    // )
    //     external
    //     view 
    //     returns(
    //         NftId poolNftId,
    //         Amount totalCollateralAmount,
    //         Amount localCollateralAmount,
    //         bool poolIsVerifyingApplications
    //     );


    // /// @dev calulate required collateral for the provided parameters.
    // /// Collateralization is applied to sum insured.
    // /// Retention level defines the fraction of the collateral that is required locally.
    // function calculateRequiredCollateral(
    //     UFixed collateralizationLevel, 
    //     UFixed retentionLevel, 
    //     Amount sumInsuredAmount
    // )
    //     external
    //     pure 
    //     returns(
    //         Amount totalCollateralAmount,
    //         Amount localCollateralAmount
    //     );

}
