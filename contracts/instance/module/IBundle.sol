// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {NftId} from "../../type/NftId.sol";
import {Fee} from "../../type/Fee.sol";
import {Seconds} from "../../type/Seconds.sol";
import {Timestamp} from "../../type/Timestamp.sol";

interface IBundle {

    struct BundleInfo {
        // slot 0
        Timestamp activatedAt; 
        Timestamp expiredAt; // no new policies starting with this timestamp
        Timestamp closedAt; // no open policies, locked amount = 0
        NftId poolNftId;
        // slot 1
        Fee fee; // bundle fee on net premium amounts
        // slot 2
        bytes filter; // required conditions for applications to be considered for collateralization by this bundle
    }
}