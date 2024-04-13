// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type Seconds is uint40;

using {
    SecondsLib.eqz,
    SecondsLib.gtz,
    SecondsLib.toInt
} for Seconds global;


library SecondsLib {

    error ErrorSecondsLibDurationTooBig(uint256 duration);

    function zero() public pure returns (Seconds) {
        return Seconds.wrap(0);
    }

    function max() public pure returns (Seconds) {
        return Seconds.wrap(_max());
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

    function toInt(Seconds duration) public pure returns (uint256) {
        return uint256(uint40(Seconds.unwrap(duration)));
    }

    function _max() internal pure returns (uint40) {
        // IMPORTANT: type nees to match with actual definition for Seconds
        return type(uint40).max;
    }
}