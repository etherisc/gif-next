// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

type Location is uint64;

using {
    LocationLib.latitude,
    LocationLib.longitude
} for Location global;

library LocationLib {

    error ErrorLatitudeInvalid(int32 amount);
    error ErrorLongitudeInvalid(int32 amount);

    int32 public constant LATITUDE_MIN = -90000000;
    int32 public constant LATITUDE_MAX = 90000000;
    int32 public constant LONGITUDE_MIN = -180000000;
    int32 public constant LONGITUDE_MAX = 180000000;

    // Constants for bit manipulation
    int64 public constant LATITUDE_MASK = int64(0x7FFFFFF);
    int64 public constant LONGITUDE_MASK = int64(0xFFFFFFF);

    function zero() public pure returns (Location) {
        return Location.wrap(0);
    }

    function toLocation(int32 latitude, int32 longitude) public pure returns (Location) {
        if (latitude < LATITUDE_MIN || latitude > LATITUDE_MAX) revert ErrorLatitudeInvalid(latitude);
        if (longitude < LONGITUDE_MIN || longitude > LONGITUDE_MAX) revert ErrorLongitudeInvalid(longitude);
        
        uint32 latPacked = uint32(latitude);
        uint32 longPacked = uint32(longitude);   
        // uint64 packed = (uint64(latPacked) << 32) | uint64(longPacked);
        return Location.wrap((uint64(latPacked) << 32) | uint64(longPacked));
    }

    function latitude(Location location) public pure returns (int32) {
        return int32(uint32(Location.unwrap(location) >> 32));
    }

    function longitude(Location location) public pure returns (int32) {
        return int32(uint32(Location.unwrap(location) & 0xFFFFFFFF));
    }

    function decimals() public pure returns (uint8) {
        return uint8(6);
    }
}