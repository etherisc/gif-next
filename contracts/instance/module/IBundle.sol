// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IBundle {
    struct BundleInfo {
        NftId poolNftId;
        Fee fee; // bundle fee on net premium amounts
        bytes filter; // required conditions for applications to be considered for collateralization by this bundle
        uint256 capitalAmount; // net investment capital + net premiums - payouts
        uint256 lockedAmount; // capital amount linked to collateralizaion of non-closed policies (<= balance)
        uint256 balanceAmount; // total amount of funds: capitalAmount + fees (balance >= captial)
        Timestamp expiredAt; // no new policies
        Timestamp closedAt; // no open policies, locked amount = 0
    }
}