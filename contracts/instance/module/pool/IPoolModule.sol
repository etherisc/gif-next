// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";
import {NftId} from "../../../types/NftId.sol";
import {IPoolService} from "../../service/IPoolService.sol";

import {IModuleBase} from "../IModuleBase.sol";

interface IPool {
    struct PoolInfo {
        NftId nftId;
        uint256 capital;
        uint256 lockedCapital;
    }
}

interface IPoolModule is IModuleBase, IPool {
    function underwrite(NftId policyNftId, NftId productNftId) external;

    function registerPool(NftId nftId) external;

    function getPoolInfo(
        NftId nftId
    ) external view returns (PoolInfo memory info);

    // repeat service linked signaturea to avoid linearization issues
    function senderIsProductService() external  returns(bool isService);
    function senderIsPoolService() external  returns(bool isService);
}
