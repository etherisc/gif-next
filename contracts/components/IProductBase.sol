// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {IComponentBase} from "./IComponentBase.sol";
import {IRegistry} from "../registry/IRegistry.sol";

interface IProductBase is IComponentBase {

    struct ProductInfo {
        IRegistry.ObjectInfo forRegistry;
        NftId instanceNftId;
        NftId tokenNftId;
        NftId poolNftId;
        NftId distributorNftId;
        address wallet;
        uint256 policyFee;
        uint256 processingFee;
    }

    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    ) external;

    function getProductInfo() external view returns(ProductInfo memory info);

    function getPoolNftId() external view returns (NftId poolNftId);

    function getPolicyFee() external view returns (Fee memory policyFee);

    function getProcessingFee() external view returns (Fee memory processingFee);
}
