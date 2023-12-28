// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../types/NftId.sol";

interface IRisk {
    struct RiskInfo {
        NftId productNftId;
        bytes data;
    }
}
