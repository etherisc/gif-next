// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type Seconds is uint40;

using {
    SecondsEq as ==,
    SecondsGt as >,
    SecondsLib.eqz,
    SecondsLib.gtz,
    SecondsLib.toInt
} for Seconds global;

function SecondsEq(Seconds duration1, Seconds duration2) pure returns (bool) {
    return SecondsLib.eq(duration1, duration2);
}

function SecondsGt(Seconds duration1, Seconds duration2) pure returns (bool) {
    return SecondsLib.gt(duration1, duration2);
}

library SecondsLib {

    error ErrorSecondsLibDurationTooBig(uint256 duration);

    function zero() public pure returns (Seconds) {
        return Seconds.wrap(0);
    }

    function max() public pure returns (Seconds) {
        return Seconds.wrap(_max());
    }

    function oneDay() public pure returns (Seconds duration) {
        return Seconds.wrap(24 * 3600);
    }

    function oneYear() public pure returns (Seconds duration) {
        return Seconds.wrap(365 * 24 * 3600);
    }

    /// @dev converts the uint duration into Seconds
    /// function reverts if duration is exceeding max Seconds value
    function toSeconds(uint256 duration) public pure returns (Seconds) {
        // if(duration > type(uint40).max) {
        if(duration > _max()) {
            revert ErrorSecondsLibDurationTooBig(duration);
        }

        return Seconds.wrap(uint40(duration));
    }

    /// @dev return true if duration equals 0
    function eqz(Seconds duration) public pure returns (bool) {
        return Seconds.unwrap(duration) == 0;
    }

    /// @dev return true if duration is larger than 0
    function gtz(Seconds duration) public pure returns (bool) {
        return Seconds.unwrap(duration) > 0;
    }

    /// @dev return true iff duration1 and duration2 are the same
    function eq(Seconds duration1, Seconds duration2) public pure returns (bool) {
        return Seconds.unwrap(duration1) == Seconds.unwrap(duration2);
    }

    /// @dev return true if duration1 is larger than duration2
    function gt(Seconds duration1, Seconds duration2) public pure returns (bool) {
        return Seconds.unwrap(duration1) > Seconds.unwrap(duration2);
    }

    function toInt(Seconds duration) public pure returns (uint256) {
        return uint256(uint40(Seconds.unwrap(duration)));
    }

    function _max() internal pure returns (uint40) {
        // IMPORTANT: type nees to match with actual definition for Seconds
        return type(uint40).max;
    }
}