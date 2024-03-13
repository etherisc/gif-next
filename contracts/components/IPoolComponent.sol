// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../types/Fee.sol";
import {IComponent} from "./IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {Seconds} from "../types/Timestamp.sol";
import {UFixed} from "../types/UFixed.sol";

/// @dev pool components hold and manage the collateral to cover active policies
/// pools come in different flavors
interface IPoolComponent is IComponent {

    error ErrorPoolNotBundleOwner(NftId bundleNftId, address caller);
    error ErrorPoolNotPoolService(address caller);

    error ErrorPoolApplicationBundleMismatch(NftId applicationNftId);
    error ErrorPoolBundleOwnerRoleAlreadySet();

    event LogPoolVerifiedByPool(address pool, NftId applicationNftId, uint256 collateralizationAmount);
    event LogPoolBundleMaxCapitalAmountUpdated(uint256 previousMaxCapitalAmount, uint256 currentMaxCapitalAmount);
    event LogPoolBundleOwnerRoleSet(RoleId bundleOwnerRole);

    /// @dev increases the staked tokens by the specified amount
    /// only the bundle owner may stake tokens
    /// bundle MUST be in active or locked state
    function stake(NftId bundleNftId, uint256 amount) external;

    /// @dev decreases the staked tokens by the specified amount
    /// only the bundle owner may unstake tokens from the bundle
    /// bundle MUST be in active, locked or closed state
    function unstake(NftId bundleNftId, uint256 amount) external;

    /// @dev extends the bundle lifetime of the bundle by the specified time
    /// only the bundle owner may extend the bundle's lifetime
    /// bundle MUST be in active or locked state
    function extend(NftId bundleNftId, Seconds lifetimeExtension) external;

    /// @dev locks the specified bundle
    /// a bundle to be locked MUST be in active state
    /// locked bundles may not be used to underwrite any new policy
    function lockBundle(NftId bundleNftId) external;

    /// @dev unlocks the specified bundle
    /// a bundle to be unlocked MUST be in locked state
    function unlockBundle(NftId bundleNftId) external;

    /// @dev close the specified bundle
    /// a bundle to be closed MUST be in active or locked state
    /// to close a bundle all all linked policies MUST be in closed state as well
    /// closing a bundle finalizes the bundle bookkeeping including overall profit calculation
    /// once a bundle is closed this action cannot be reversed
    function close(NftId bundleNftId) external;

    /// @dev sets the fee for the specified bundle
    /// the fee is added on top of the poolFee and deducted from the premium amounts
    /// via these fees individual bundler owner may earn income per policy in the context of peer to peer pools
    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    ) external;

    /// @dev sets the maximum overall capital amound held by this pool
    /// function may only be called by pool owner
    function setMaxCapitalAmount(uint256 maxCapitalAmount) external;

    /// @dev sets the required role to create/own bundles
    /// may only be called once after setting up a pool
    /// may only be called by pool owner 
    function setBundleOwnerRole(RoleId bundleOwnerRole) external;

    /// @dev update pool fees to the specified values
    /// pool fees: are deducted from the premium amount and goes to the pool owner
    /// staking fees: are deducted from the staked tokens by a bundle owner and goes to the pool owner
    /// performance fees: when a bundle is closed a bundle specific profit is calculated
    /// the performance fee is deducted from this profit and goes to the pool owner
    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    /// @dev this is a callback function that is called by the product service when underwriting a policy.
    /// the pool has the option to check the details and object to underwriting by reverting.
    /// the function is only called for "active" pools that ask to be involved/notified
    /// by product related state changes.
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    ) external;

    /// @dev defines the multiplier to calculate the required collateral to cover a given sum insured amount
    /// default implementation returns 100%
    function getCollateralizationLevel() external view returns (UFixed collateralizationLevel);

    /// @dev defines the amount of collateral held in the pool.
    /// if the value is < 100% the pool is required to hold a policy that covers the locally missing collateral
    /// default implementation returns 100%
    function getRetentionLevel() external view returns (UFixed retentionLevel);

    /// @dev declares if pool relies on external management of collateral (yes/no): 
    /// - yes: underwriting of new policies does not require an actual token balance, instead it is assumed that the pool owner will manage funds externally and inject enough tokens to allow process confirmed payouts
    /// - no: the pool smart contract ensures that the necessary capacity of the pool prior to underwriting.
    /// default implementation returns false (no)
    function isExternallyManaged() external view returns (bool);

    /// @dev declares if pool component is actively involved in underwriting (yes/no): 
    /// - yes: verifying pools components actively confirm underwriting applications, ie the pool component logic explicitly needs to confirm the locking of collateral to cover the sum insured of the policy
    /// - no: underwriting a policy does not require any interaction with the pool component if the covering bundle can provide the necessary captial
    /// default implementation returnsfalse (no)
    function isVerifyingApplications() external view returns (bool);

    /// @dev returns the maximum overall capital amound held by this pool
    function getMaxCapitalAmount() external view returns (uint256 maxCapitalAmount);

    /// @dev declares if pool intercept transfers of bundle nft ids
    /// - yes: pool may block transfer of bundle ownership or simply updates some bookkeeping related to bundle ownership. callback function is nftTransferFrom
    /// - no: pool is not involved in transfer of bundle ownership
    /// default implementation returns false (no)
    function isInterceptingBundleTransfers() external view returns (bool);

    /// @dev returns the required role for bundle owners
    /// default emplementation returns PUBLIC_ROLE
    /// the PUBLIC_ROLE role implies that no specific roole is required for bundle owners
    function getBundleOwnerRole() external view returns (RoleId bundleOwnerRole);

    /// @dev returns true iff the application matches with the bundle 
    /// this is a callback function that is only called if a pool declares itself as a verifying pool
    /// default implementation returns true
    function applicationMatchesBundle(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    )
        external
        view
        returns (bool isMatching);

    /// @dev returns setup infos for this pool
    /// when registered with an instance the setup info is obtained from the data stored in the instance
    /// when not registered the function returns the initial setup info
    function getSetupInfo() external view returns (ISetup.PoolSetupInfo memory setupInfo);

}
