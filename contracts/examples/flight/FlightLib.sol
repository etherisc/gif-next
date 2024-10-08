// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IPolicy} from "../../instance/module/IPolicy.sol";
import {IPolicyService} from "../../product/IPolicyService.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {FlightMessageVerifier} from "./FlightMessageVerifier.sol";
import {FlightProduct} from "./FlightProduct.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId} from "../../type/NftId.sol";
import {RequestId} from "../../type/RequestId.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {StateId} from "../../type/StateId.sol";
import {Str} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";


library FlightLib {

    function checkApplicationData(
        FlightProduct flightProduct,
        Str flightData, 
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premiumAmount
    )
        public
        view
    {
        _checkApplicationData(flightProduct, premiumAmount, arrivalTime, departureTime);
    }


    function _checkApplicationData(
        FlightProduct flightProduct,
        Amount premiumAmount,
        Timestamp arrivalTime,
        Timestamp departureTime
    )
        internal
        view
    {
        // solhint-disable
        if (premiumAmount < flightProduct.MIN_PREMIUM()) {
            revert FlightProduct.ErrorFlightProductPremiumAmountTooSmall(premiumAmount, flightProduct.MIN_PREMIUM());
        }
        if (premiumAmount > flightProduct.MAX_PREMIUM()) {
            revert FlightProduct.ErrorFlightProductPremiumAmountTooLarge(premiumAmount, flightProduct.MAX_PREMIUM());
        }
        if (arrivalTime <= departureTime) {
            revert FlightProduct.ErrorFlightProductArrivalBeforeDepartureTime(departureTime, arrivalTime);
        }

        if (arrivalTime > departureTime.addSeconds(flightProduct.MAX_FLIGHT_DURATION())) {
            revert FlightProduct.ErrorFlightProductArrivalAfterMaxFlightDuration(arrivalTime, departureTime, flightProduct.MAX_FLIGHT_DURATION());
        }
        if (departureTime < TimestampLib.current().addSeconds(flightProduct.MIN_TIME_BEFORE_DEPARTURE())) {
            revert FlightProduct.ErrorFlightProductDepartureBeforeMinTimeBeforeDeparture(departureTime, TimestampLib.current(), flightProduct.MIN_TIME_BEFORE_DEPARTURE());
        }
        if (departureTime > TimestampLib.current().addSeconds(flightProduct.MAX_TIME_BEFORE_DEPARTURE())) {
            revert FlightProduct.ErrorFlightProductDepartureAfterMaxTimeBeforeDeparture(departureTime, TimestampLib.current(), flightProduct.MAX_TIME_BEFORE_DEPARTURE());
        }
        // solhint-enable
    }


    /// @dev calculates payout option based on flight status and delay minutes.
    /// Is not a view function as it emits log evens in case of unexpected status.
    // TODO decide if reverts instead of log events could work too (and convert the function into a view function)
    function checkAndGetPayoutOption(
        RequestId requestId,
        RiskId riskId, 
        bytes1 status, 
        int256 delayMinutes
    )
        public
        returns (uint8 payoutOption)
    {
        // default: no payout
        payoutOption = type(uint8).max;

        // check status
        if (status != "L" && status != "A" && status != "C" && status != "D") {
            emit FlightProduct.LogErrorUnprocessableStatus(requestId, riskId, status);
            return payoutOption;
        }

        if (status == "A") {
            // todo: active, reschedule oracle call + 45 min
            emit FlightProduct.LogErrorUnexpectedStatus(requestId, riskId, status, delayMinutes);
            return payoutOption;
        }

        // trigger payout if applicable
        if (status == "C") { payoutOption = 3; } 
        else if (status == "D") { payoutOption = 4; } 
        else if (delayMinutes >= 15 && delayMinutes < 30) { payoutOption = 0; } 
        else if (delayMinutes >= 30 && delayMinutes < 45) { payoutOption = 1; } 
        else if (delayMinutes >= 45) { payoutOption = 2; }
    }


    function calculateWeight(
        FlightProduct flightProduct,
        uint256[6] memory statistics
    )
        public
        view
        returns (uint256 weight)
    {
        // check we have enough observations
        if (statistics[0] < flightProduct.MIN_OBSERVATIONS()) {
            revert FlightProduct.ErrorFlightProductNotEnoughObservations(statistics[0], flightProduct.MIN_OBSERVATIONS());
        }

        weight = 0;
        for (uint256 i = 1; i < 6; i++) {
            weight += flightProduct.WEIGHT_PATTERN(i) * statistics[i] * 10000 / statistics[0];
        }

        // To avoid div0 in the payout section, we have to make a minimal assumption on weight
        if (weight == 0) {
            weight = 100000 / statistics[0];
        }

        // TODO comment on intended effect
        weight = (weight * (100 + flightProduct.MARGIN_PERCENT())) / 100;
    }


    // REMARK: each flight may get different payouts depending on the latest statics
    function calculatePayoutAmounts(
        FlightProduct flightProduct,
        Amount premium, 
        uint256[6] memory statistics
    )
        public
        view
        returns (
            uint256 weight, 
            Amount[5] memory payoutAmounts,
            Amount sumInsuredAmount // simply the max of payoutAmounts 
        )
    {
        if (premium < flightProduct.MIN_PREMIUM()) { 
            revert FlightProduct.ErrorFlightProductPremiumAmountTooSmall(premium, flightProduct.MIN_PREMIUM()); 
        }
        if (premium > flightProduct.MAX_PREMIUM()) { 
            revert FlightProduct.ErrorFlightProductPremiumAmountTooLarge(premium, flightProduct.MAX_PREMIUM()); 
        }

        sumInsuredAmount = AmountLib.zero();
        weight = calculateWeight(flightProduct, statistics);

        for (uint256 i = 0; i < 5; i++) {
            Amount payoutAmount = AmountLib.toAmount(
                premium.toInt() * flightProduct.WEIGHT_PATTERN(i + 1) * 10000 / weight);

            // cap payout and update sum insured if applicable
            if (payoutAmount > flightProduct.MAX_PAYOUT()) { payoutAmount = flightProduct.MAX_PAYOUT(); }
            if (payoutAmount > sumInsuredAmount) { sumInsuredAmount = payoutAmount; }

            payoutAmounts[i] = payoutAmount;
        }
    }


    function getPayoutOption(
        InstanceReader reader,
        NftId productNftId,
        RiskId riskId
    )
        public
        view
        returns (
            bool exists,
            bool statusAvailable,
            uint8 payoutOption
        )
    {
        FlightProduct.FlightRisk memory flightRisk;
        (exists, flightRisk) = getFlightRisk(
            reader, 
            productNftId, 
            riskId);
        
        statusAvailable = flightRisk.statusUpdatedAt.gtz();
        payoutOption = flightRisk.payoutOption;
    }


    function getPayoutAmount(
        bytes memory applicationData, 
        uint8 payoutOption
    )
        public
        pure
        returns (Amount payoutAmount)
    {
        // retrieve payout amounts from application data
        (, Amount[5] memory payoutAmounts) = abi.decode(
            applicationData, (Amount, Amount[5]));

        // get payout amount for selected option
        payoutAmount = payoutAmounts[payoutOption];
    }


    function getFlightRisk(
        InstanceReader reader,
        NftId productNftId, 
        Str flightData,
        Timestamp departureTime, 
        string memory departureTimeLocal,
        Timestamp arrivalTime,
        string memory arrivalTimeLocal
    )
        public
        view
        returns (
            RiskId riskId,
            bool exists,
            FlightProduct.FlightRisk memory flightRisk
        )
    {
        riskId = getRiskId(productNftId, flightData);
        (exists, flightRisk) = getFlightRisk(reader, productNftId, riskId);

        // create new risk if not existing
        if (!exists) {
            flightRisk = FlightProduct.FlightRisk({
                flightData: flightData,
                departureTime: departureTime,
                departureTimeLocal: departureTimeLocal,
                arrivalTime: arrivalTime,
                arrivalTimeLocal: arrivalTimeLocal,
                sumOfSumInsuredAmounts: AmountLib.toAmount(0),
                status: bytes1(0),
                delayMinutes: 0,
                payoutOption: uint8(0),
                statusUpdatedAt: TimestampLib.zero()});
        }
    }


    function getFlightRisk(
        InstanceReader reader,
        NftId productNftId,
        RiskId riskId
    )
        public
        view
        returns (
            bool exists,
            FlightProduct.FlightRisk memory flightRisk
        )
    {
        // check if risk exists
        exists = reader.isProductRisk(productNftId, riskId);

        // get risk data if risk exists
        if (exists) {
            flightRisk = abi.decode(
                reader.getRiskInfo(riskId).data, (FlightProduct.FlightRisk));
        }
    }


    function getRiskId(
        NftId productNftId,
        Str flightData
    )
        public
        view 
        returns (RiskId riskId)
    {
        bytes32 riskKey = getRiskKey(flightData);
        riskId = getRiskId(productNftId, riskKey);
    }


    function getRiskKey(
        Str flightData
    )
        internal
        pure
        returns (bytes32 riskKey)
    {
        return keccak256(abi.encode(flightData));
    }


    function getRiskId(NftId productNftId, bytes32 riskKey) internal view returns (RiskId riskId) {
        return RiskIdLib.toRiskId(productNftId, riskKey);
    }
}