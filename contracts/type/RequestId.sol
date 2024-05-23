// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32, KeyId, Key32Lib} from "./Key32.sol";
import {REQUEST} from "./ObjectType.sol";

type RequestId is uint64;

// type bindings
using {
    eqRequestId as ==, 
    neRequestId as !=,
    RequestIdLib.eqz,
    RequestIdLib.gtz,
    RequestIdLib.toInt,
    RequestIdLib.toKey32
} for RequestId global;

// general pure free functions

function eqRequestId(RequestId a, RequestId b) pure returns (bool isSame) {
    return RequestIdLib.eq(a, b);
}

function neRequestId(RequestId a, RequestId b) pure returns (bool isSame) {
    return RequestIdLib.ne(a, b);
}

library RequestIdLib {

    // @dev zero element to refer to a non existing/initialized request
    function zero() public pure returns (RequestId) {
        return RequestId.wrap(0);
    }

    // @dev Converts an int id into a request id.
    function toRequestId(uint256 id) public pure returns (RequestId) {
        return RequestId.wrap(uint64(id));
    }

    // @dev Converts a request id back to an int value.
    function toInt(RequestId requestId) public pure returns (uint256) {
        return RequestId.unwrap(requestId);
    }

    // @dev Returns true iff request id a == 0
    function eqz(RequestId a) public pure returns (bool) {
        return RequestId.unwrap(a) == 0;
    }

    // @dev Returns true iff request id a > 0
    function gtz(RequestId a) public pure returns (bool) {
        return RequestId.unwrap(a) > 0;
    }

    // @dev Returns true iff risk ids a and b are identical
    function eq(RequestId a, RequestId b) public pure returns (bool isSame) {
        return RequestId.unwrap(a) == RequestId.unwrap(b);
    }

    // @dev Returns true iff risk ids a and b are different
    function ne(RequestId a, RequestId b) public pure returns (bool isSame) {
        return RequestId.unwrap(a) != RequestId.unwrap(b);
    }

    /// @dev Returns the key32 value for the specified nft id and object type.
    function toKey32(RequestId id) public pure returns (Key32 key) {
        return Key32Lib.toKey32(REQUEST(), toKeyId(id));
    }

    /// @dev Returns the key id value for the specified nft id
    function toKeyId(RequestId id) public pure returns (KeyId keyId) {
        return KeyId.wrap(bytes31(uint248(RequestId.unwrap(id))));
    }
}
