// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @dev Target: Cover 10 years with 1 ms block times.
/// Typical block times are a few seconds.
type Blocknumber is uint40;

using {
    gtBlocknumber as >,
    gteBlocknumber as >=,
    ltBlocknumber as <,
    lteBlocknumber as <=,
    eqBlocknumber as ==,
    neBlocknumber as !=,
    BlocknumberLib.toInt,
    BlocknumberLib.eq,
    BlocknumberLib.ne,
    BlocknumberLib.eqz,
    BlocknumberLib.gtz,
    BlocknumberLib.gt,
    BlocknumberLib.gte,
    BlocknumberLib.lt,
    BlocknumberLib.lte
} for Blocknumber global;

/// @dev return true if Blocknumber a is greater than Blocknumber b
function gtBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) > Blocknumber.unwrap(b);
}

/// @dev return true if Blocknumber a is greater than or equal to Blocknumber b
function gteBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) >= Blocknumber.unwrap(b);
}

/// @dev return true if Blocknumber a is less than Blocknumber b
function ltBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) < Blocknumber.unwrap(b);
}

/// @dev return true if Blocknumber a is less than or equal to Blocknumber b
function lteBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) <= Blocknumber.unwrap(b);
}

/// @dev return true if Blocknumber a is equal to Blocknumber b
function eqBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) == Blocknumber.unwrap(b);
}

/// @dev return true if Blocknumber a is not equal to Blocknumber b
function neBlocknumber(Blocknumber a, Blocknumber b) pure returns (bool) {
    return Blocknumber.unwrap(a) != Blocknumber.unwrap(b);
}


library BlocknumberLib {

    function zero() public pure returns (Blocknumber) {
        return Blocknumber.wrap(0);
    }

    function max() public pure returns (Blocknumber) {
        return Blocknumber.wrap(type(uint40).max);
    }

    function current() public view returns (Blocknumber) {
        return Blocknumber.wrap(uint40(block.number));
    }

    function toBlocknumber(uint256 blocknum) public pure returns (Blocknumber) {
        return Blocknumber.wrap(uint32(blocknum));
    }

    /// @dev return true iff blocknumber is 0
    function eqz(Blocknumber blocknumber) public pure returns (bool) {
        return Blocknumber.unwrap(blocknumber) == 0;
    }

    /// @dev return true iff blocknumber is > 0
    function gtz(Blocknumber blocknumber) public pure returns (bool) {
        return Blocknumber.unwrap(blocknumber) > 0;
    }

    /// @dev return true if Blocknumber a is greater than Blocknumber b
    function gt(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isAfter) {
        return gtBlocknumber(a, b);
    }

    /// @dev return true if Blocknumber a is greater than or equal to Blocknumber b
    function gte(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isAfterOrSame) {
        return gteBlocknumber(a, b);
    }

    /// @dev return true if Blocknumber a is less than Blocknumber b
    function lt(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isBefore) {
        return ltBlocknumber(a, b);
    }

    /// @dev return true if Blocknumber a is less than or equal to Blocknumber b
    function lte(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isBeforeOrSame) {
        return lteBlocknumber(a, b);
    }

    /// @dev return true if Blocknumber a is equal to Blocknumber b
    function eq(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isSame) {
        return eqBlocknumber(a, b);
    }

    /// @dev return true if Blocknumber a is not equal to Blocknumber b
    function ne(
        Blocknumber a,
        Blocknumber b
    ) public pure returns (bool isDifferent) {
        return neBlocknumber(a, b);
    }

    /// @dev converts the Blocknumber to a uint256
    function toInt(Blocknumber blocknumber) public pure returns (uint256) {
        return uint256(uint32(Blocknumber.unwrap(blocknumber)));
    }
}
