// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Blocknumber, BlocknumberLib} from "../../type/Blocknumber.sol";
import {NftId} from "../../type/NftId.sol";
import {Amount} from "../../type/Amount.sol";

contract ObjectCounter {

    // TODO refactor risk id
    // mapping(NftId productNftId => uint64 risks) private _riskCounter;

    uint64 private _requestCounter;

    // TODO introduce RequestId (uint64)
    function _createNextRequestId() internal returns (uint64 requestId) {
        _requestCounter++;
        return _requestCounter;
    }
}
