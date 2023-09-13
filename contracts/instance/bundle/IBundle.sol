// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";
import {NftId} from "../../types/NftId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IBundle {

    struct BundleInfo {
        NftId nftId;
        StateId state; // active, paused, closed
        bytes filter; // required conditions for applications to be considered for collateralization by this bundle
        uint256 capital; // net investment capital amount (<= balance)
        uint256 lockedCapital; // capital amount linked to collateralizaion of non-closed policies (<= capital)
        uint256 balance; // total amount of funds: net investment capital + net premiums - payouts
        // TODO decide; do we need lifetime or is expiredAt > 0 sufficient?
        // uint256 lifetime; // createdAt + lifetime >= expiredAt
        Timestamp createdAt;
        Timestamp expiredAt; // no new policies
        Timestamp updatedAt;
    }
}

interface IBundleModule is IBundle {

    function createBundle(
        IRegistry.RegistryInfo memory bundleInfo,
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    ) external returns(NftId nftId);

    function fundBundle(NftId bundleNftId, uint256 amount) external;
    function defundBundle(NftId bundleNftId, uint256 amount) external;

    function pauseBundle(NftId bundleNftId) external;
    function activateBundle(NftId bundleNftId) external;
    function extendBundle(NftId bundleNftId, uint256 lifetimeExtension) external;
    function closeBundle(NftId bundleNftId) external;

    function collateralizePolicy(NftId bundleNftId, NftId policyNftId, uint256 collateralAmount) external;
    function releasePolicy(NftId bundleNftId, NftId policyNftId) external returns(uint256 collateralAmount);

    function processPremium(uint256 bundleId, bytes32 processId, uint256 amount) external;
    function processPayout(uint256 bundleId, bytes32 processId, uint256 amount) external;

}
