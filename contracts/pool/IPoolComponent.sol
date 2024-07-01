// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {UFixed} from "../type/UFixed.sol";

/// @dev pool components hold and manage the collateral to cover active policies
/// pools come in different flavors
interface IPoolComponent is IInstanceLinkedComponent {

    error ErrorPoolNotBundleOwner(NftId bundleNftId, address caller);
    error ErrorPoolNotPoolService(address caller);
    error ErrorPoolApplicationBundleMismatch(NftId applicationNftId);

    event LogPoolVerifiedByPool(address pool, NftId applicationNftId, Amount collateralizationAmount);

    /// @dev this is a callback function that is called by the product service when underwriting a policy.
    /// the pool has the option to check the details and object to underwriting by reverting.
    /// the function is only called for "active" pools that ask to be involved/notified
    /// by product related state changes.
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    ) external;

    /// @dev returns true iff the application matches with the bundle 
    /// this is a callback function that is only called if a pool declares itself as a verifying pool
    /// default implementation returns true
    function applicationMatchesBundle(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    )
        external
        view
        returns (bool isMatching);

    /// @dev Withdraw bundle feeds for the given bundle
    /// @param bundleNftId the bundle Nft Id
    /// @param amount the amount to withdraw. If set to UINT256_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawBundleFees(NftId bundleNftId, Amount amount) external returns (Amount withdrawnAmount);

    /// @dev returns initial pool specific infos for this pool
    function getInitialPoolInfo() external view returns (IComponents.PoolInfo memory info);

}
