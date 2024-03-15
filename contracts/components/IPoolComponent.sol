// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../types/Fee.sol";
import {IComponent} from "./IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {RoleId} from "../types/RoleId.sol";
import {Seconds} from "../types/Seconds.sol";
import {UFixed} from "../types/UFixed.sol";

/// @dev pool components hold and manage the collateral to cover active policies
/// pools come in different flavors
interface IPoolComponent is IComponent {

    error ErrorPoolNotBundleOwner(NftId bundleNftId, address caller);
    error ErrorPoolNotPoolService(address caller);

    error ErrorPoolApplicationBundleMismatch(NftId applicationNftId);

    event LogPoolVerifiedByPool(address pool, NftId applicationNftId, uint256 collateralizationAmount);

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

    // TODO move this to IComponent if this works ...
    /// @dev returns component infos for this pool
    /// when registered with an instance the info is obtained from the data stored in the instance
    /// when not registered the function returns the info from the component contract
    function getComponentInfo() external view returns (ISetup.ComponentInfo memory info);

    /// @dev returns pool specific infos for this pool
    /// when registered with an instance the info is obtained from the data stored in the instance
    /// when not registered the function returns the info from the component contract
    function getPoolInfo() external view returns (ISetup.PoolInfo memory info);

}
