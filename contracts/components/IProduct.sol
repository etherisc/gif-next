// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";

interface IProductComponent {
    function getPoolNftId() external view returns (NftId poolNftId);

    function getPolicyFee() external view returns (Fee memory policyFee);

    function getProcessingFee()
        external
        view
        returns (Fee memory processingFee);
}
