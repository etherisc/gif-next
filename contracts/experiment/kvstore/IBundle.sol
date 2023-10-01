// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {Blocknumber} from "../../types/Blocknumber.sol";

interface IBundle {

    struct BundleInfo {
        NftId nftId;
        NftId poolNftId;
        bytes filter; // required conditions for applications to be considered for collateralization by this bundle
        uint256 capitalAmount; // net investment capital amount (<= balance)
        uint256 lockedAmount; // capital amount linked to collateralizaion of non-closed policies (<= balance)
        uint256 balanceAmount; // total amount of funds: net investment capital + net premiums - payouts
        Timestamp expiredAt; // no new policies
        Timestamp closedAt;
    }
}
