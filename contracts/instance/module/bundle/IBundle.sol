// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";
import {Fee} from "../../../types/Fee.sol";
import {Key32} from "../../../types/Key32.sol";
import {NftId} from "../../../types/NftId.sol";
import {StateId} from "../../../types/StateId.sol";
import {Timestamp} from "../../../types/Timestamp.sol";
import {Blocknumber} from "../../../types/Blocknumber.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

interface IBundle {

    struct BundleInfo {
        NftId poolNftId;
        Fee fee; // bundle fee on net premium amounts
        bytes filter; // required conditions for applications to be considered for collateralization by this bundle
        uint256 capitalAmount; // net investment capital amount (<= balance)
        uint256 lockedAmount; // capital amount linked to collateralizaion of non-closed policies (<= balance)
        uint256 balanceAmount; // total amount of funds: net investment capital + net premiums - payouts
        Timestamp expiredAt; // no new policies
        Timestamp closedAt;
    }
}

interface IBundleModule is IBundle {

    function createBundleInfo(
        NftId bundleNftId,
        NftId poolNftId,
        Fee memory fee,
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    ) external;

    function setBundleInfo(NftId nftId, BundleInfo memory bundleInfo) external;
    function updateBundleState(NftId nftId, StateId state) external;

    function collateralizePolicy(NftId bundleNftId, NftId policyNftId, uint256 amount) external;
    function releasePolicy(NftId bundleNftId, NftId policyNftId) external returns(uint256 collateralAmount);

    function getBundleInfo(NftId nftId) external view returns(BundleInfo memory bundleInfo);

    // repeat service linked signatures to avoid linearization issues
    function getProductService() external returns(IProductService);
    function getPoolService() external returns(IPoolService);
}
