// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IComponents} from "./module/IComponents.sol";

import {Key32} from "../type/Key32.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {LibRequestIdSet} from "../type/RequestIdSet.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectSet} from "./base/ObjectSet.sol";
import {ObjectSetHelperLib} from "./base/ObjectSetHelperLib.sol";
import {RequestId} from "../type/RequestId.sol";

contract RequestSet is 
    ObjectSet
{
    using LibNftIdSet for LibNftIdSet.Set;
    using LibRequestIdSet for LibRequestIdSet.Set;

    event LogRequestSetRequestAdded(NftId indexed oracleNftId, RequestId indexed requestId);
    event LogRequestSetRequestRemoved(NftId indexed oracleNftId, RequestId indexed requestId);

    error ErrorRequestSetOracleNotRegistered(NftId oracleNftId);

    /// @dev add a new request to a oracle registerd with this instance
    // the corresponding oracles existence is checked via instance reader
    function add(NftId oracleNftId, RequestId requestId) external restricted() {
        IComponents.ComponentInfo memory componentInfo = ObjectSetHelperLib.getComponentInfo(_instanceAddress, oracleNftId);

        // ensure pool is registered with instance
        if (bytes(componentInfo.name).length == 0) {
            revert ErrorRequestSetOracleNotRegistered(oracleNftId);
        }

        _add(oracleNftId, _toRequestKey32(requestId));
        emit LogRequestSetRequestAdded(oracleNftId, requestId);
    }

    function remove(NftId oracleNftId, RequestId requestId) external restricted() {
        _remove(oracleNftId, _toRequestKey32(requestId));
        emit LogRequestSetRequestRemoved(oracleNftId, requestId);
    }

    function _toRequestKey32(RequestId requestId) private pure returns (Key32) {
        return requestId.toKey32();
    }
}