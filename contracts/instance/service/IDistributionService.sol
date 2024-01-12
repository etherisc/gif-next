// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {IService} from "../../shared/IService.sol";

interface IDistributionService is IService {
    function setFees(
        Fee memory distributionFee
    ) external;
}
