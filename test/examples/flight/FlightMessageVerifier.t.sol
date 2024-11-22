// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console} from "../../../lib/forge-std/src/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {INftOwnable} from "../../../contracts/shared/INftOwnable.sol";

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ACTIVE} from "../../../contracts/type/StateId.sol";
import {FlightBaseTest} from "./FlightBase.t.sol";
// TODO remove this comment
import {FlightMessageVerifier} from "../../../contracts/examples/flight/FlightMessageVerifier.sol";
import {Str, StrLib} from "../../../contracts/type/String.sol";
import {SecondsLib} from "../../../contracts/type/Seconds.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";


// solhint-disable func-name-mixedcase
contract FlightMessageVerifierTest is FlightBaseTest {

    // sample test data
    Str public flightData = StrLib.toStr("LX 180 ZRH BKK 20241104");
    Timestamp public departureTime = TimestampLib.toTimestamp(1731085200);
    Timestamp public arrivalTime = TimestampLib.toTimestamp(1731166800);
    Amount public premiumAmount;

    uint256[6] public statistics = [
        uint256(20), // total number of flights
        2, // number of flights late 15'
        5, // number of flights late 30'
        3, // number of flights late 45'
        1, // number of flights cancelled
        0 // number of flights diverted
    ];


    function setUp() public override {
        super.setUp();

        premiumAmount = AmountLib.toAmount(15 * 10 ** flightUSD.decimals());
    }


    function test_flightMessageVerifierSetup() public view {
        // GIVEN - setp from flight base test

        // solhint-disable
        console.log("");
        console.log("flight message verifier", address(flightMessageVerifier));
        console.log("flight message verifier owner (direct)", verifierOwner);
        console.log("flight message verifier owner (via verifier)", flightMessageVerifier.owner());
        console.log("flight message verifier expected signer", flightMessageVerifier.getExpectedSigner());
        console.log("data signer", dataSigner);
        console.log("data signer pk", dataSignerPrivateKey);
        // solhint-enable

        // THEN
        assertEq(flightMessageVerifier.owner(), verifierOwner, "unexpected message verifier owner");
        assertEq(flightMessageVerifier.getExpectedSigner(), dataSigner, "unexpected message data signer");
    }


    function test_flightMessageVerfierCreateAndVerifyRatingsMessageHappyCase() public view {
        // GIVEN - setp from flight base test

        bytes32 ratingsHash = flightMessageVerifier.getRatingsHash(
            flightData, 
            departureTime, 
            arrivalTime, 
            premiumAmount, 
            statistics);

        // solhint-disable-next-line
        console.log("ratings hash", vm.toString(ratingsHash));

        // TODO check preference v,r,s vs a single singature
        // bytes memory signature = _getSignature(dataSignerPrivateKey, ratingsHash);
        // assertEq(signature.length, 65);
        // console.log("signature", vm.toString(signature));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dataSignerPrivateKey, ratingsHash);

        // WHEN
        (
            address actualSigner,
            ECDSA.RecoverError errorStatus,
            bool success
        ) = flightMessageVerifier.verifyRatingsHash(
            flightData,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics,
            v, r, s);

        // solhint-disable
        console.log("actual signer", actualSigner);
        console.log("error status", uint256(errorStatus));
        console.log("success", success);
        // solhint-enable

        // THEN
        assertTrue(success, "signature verification failed");
        assertEq(actualSigner, dataSigner, "unexpected signer");
    }


    function test_flightMessageVerfierCreateAndVerifyRatingsMessageManipulatedData() public view {
        // GIVEN - setp from flight base test

        // manipulate arrival time by subtracting 1 hour (to guarantee a delay > 45')
        Timestamp manipulatedArrivalTime = TimestampLib.toTimestamp(
            arrivalTime.toInt() - 3600);

        bytes32 ratingsHash = flightMessageVerifier.getRatingsHash(
            flightData, 
            departureTime, 
            manipulatedArrivalTime, 
            premiumAmount, 
            statistics);

        // solhint-disable-next-line
        console.log("ratings hash", vm.toString(ratingsHash));

        // TODO check preference v,r,s vs a single singature
        // bytes memory signature = _getSignature(dataSignerPrivateKey, ratingsHash);
        // assertEq(signature.length, 65);
        // console.log("signature", vm.toString(signature));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dataSignerPrivateKey, ratingsHash);

        // WHEN
        (
            address actualSigner,
            ECDSA.RecoverError errorStatus,
            bool success
        ) = flightMessageVerifier.verifyRatingsHash(
            flightData,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics,
            v, r, s);

        // solhint-disable
        console.log("actual signer", actualSigner);
        console.log("error status", uint256(errorStatus));
        console.log("success", success);
        // solhint-enable

        // THEN
        assertTrue(actualSigner != dataSigner, "actual signer not different from data signer");
        assertFalse(success, "signature verification passed unexpectedly");
    }


    function _getSignature(uint256 privateKey, bytes32 messageHash) internal view returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        // TODO fix this, creating signature from v,r,s like this does not seem to work with oz ECDSA
        signature = abi.encodePacked(v, r, s);
    }
}