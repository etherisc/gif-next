// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../type/NftId.sol";
import {RequestId, RequestIdLib} from "../../type/RequestId.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";

contract ObjectCounter {

    mapping(NftId productNftId => uint64 risks) private _riskCounter;
    uint256 private _requestCounter = 0;

    function _createNextRequestId() internal returns (RequestId requestId) {
        _requestCounter++;
        requestId = RequestIdLib.toRequestId(_requestCounter);
    }

    function _createNextRiskId(NftId productNftId) internal returns (RiskId riskId) {
        _riskCounter[productNftId]++;
        riskId = RiskIdLib.toRiskId(_riskCounter[productNftId]);
    }
}
