// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {Location, LocationLib} from "../../contracts/examples/crop/Location.sol";

contract LocationTest is Test {

    function test_days() public {
        assertEq(uint256(1 minutes), 60, "unexpected seconds for minute");
        assertEq(uint256(1 hours), 3600, "unexpected seconds for hour");
        assertEq(uint256(1 days), 24 * 3600, "unexpected seconds for day");
    }

    function test_locationToZurich() public {
        // GIVEN
        int32 latitude = 47367394;
        int32 longitude = 8542192;

        // WHEN
        Location location = LocationLib.toLocation(latitude, longitude);

        // THEN
        assertEq(LocationLib.latitude(location), latitude, "unexpected latitude");
        assertEq(LocationLib.longitude(location), longitude, "unexpected longitude");
    }

    function test_locationLatLongMinMax() public {
        assertEq(LocationLib.LATITUDE_MIN, -90000000, "unexpected LATITUDE_MIN");
        assertEq(LocationLib.LATITUDE_MAX, 90000000, "unexpected LATITUDE_MAX");
        assertEq(LocationLib.LONGITUDE_MIN, -180000000, "unexpected LONGITUDE_MIN");
        assertEq(LocationLib.LONGITUDE_MAX, 180000000, "unexpected LONGITUDE_MAX");

        assertEq(LocationLib.LATITUDE_MIN / int32(uint32(10**LocationLib.decimals())), -90, "unexpected LATITUDE_MIN (rounded)");
        assertEq(LocationLib.LATITUDE_MAX / int32(uint32(10**LocationLib.decimals())), 90, "unexpected LATITUDE_MAX (rounded)");
        assertEq(LocationLib.LONGITUDE_MIN / int32(uint32(10**LocationLib.decimals())), -180, "unexpected LONGITUDE_MIN (rounded)");
        assertEq(LocationLib.LONGITUDE_MAX / int32(uint32(10**LocationLib.decimals())), 180, "unexpected LONGITUDE_MAX (rounded)");
    }

    function test_locationZero() public {
        Location locationZero = LocationLib.toLocation(0, 0);
        assertEq(LocationLib.latitude(locationZero), 0, "unexpected latitude");
        assertEq(LocationLib.longitude(locationZero), 0, "unexpected longitude");

        assertEq(LocationLib.latitude(LocationLib.zero()), 0, "unexpected latitude (zero)");
        assertEq(LocationLib.longitude(LocationLib.zero()), 0, "unexpected longitude (zero)");
    }

    function test_locationToLatLongMaxMin() public {
        // GIVEN
        int32 latitudeMin = LocationLib.LATITUDE_MIN;
        int32 latitudeMax = LocationLib.LATITUDE_MAX;
        int32 longitudeMin = LocationLib.LONGITUDE_MIN;
        int32 longitudeMax = LocationLib.LONGITUDE_MAX;

        // WHEN
        Location locationMin = LocationLib.toLocation(latitudeMin, longitudeMin);
        Location locationMax = LocationLib.toLocation(latitudeMax, longitudeMax);

        // THEN
        assertEq(LocationLib.latitude(locationMin), latitudeMin, "unexpected latitude min");
        assertEq(LocationLib.longitude(locationMin), longitudeMin, "unexpected longitude min");
        assertEq(LocationLib.latitude(locationMax), latitudeMax, "unexpected latitude max");
        assertEq(LocationLib.longitude(locationMax), longitudeMax, "unexpected longitude max");
    }
}