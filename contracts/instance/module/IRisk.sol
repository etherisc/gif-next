// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../type/NftId.sol";
import {Timestamp} from "../../type/Timestamp.sol";

interface IRisk {

    struct RiskInfo {
        // slot 0
        NftId productNftId;
        Timestamp createdAt;
        // slot 1
        bytes data;
    }
}
