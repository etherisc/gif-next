// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
// import {IPolicy} from "../../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
// import {ClaimId} from "../../type/ClaimId.sol";
import {FeeLib} from "../../type/Fee.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
// import {PayoutId} from "../../type/PayoutId.sol";
// import {POLICY, BUNDLE} from "../../type/ObjectType.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {Seconds, SecondsLib} from "../../type/Seconds.sol";
import {Str} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";
// import {UFixed, UFixedLib} from "../../type/UFixed.sol";


/// @dev FlightProduct implements the flight delay product.
contract FlightProduct is
    BasicProduct
{

    event LogRequestFlightRatings(uint256 requestId, bytes32 carrierFlightNumber, uint256 departureTime, uint256 arrivalTime, bytes32 riskId);
    event LogRequestFlightStatus(uint256 requestId, uint256 arrivalTime, bytes32 carrierFlightNumber, bytes32 departureYearMonthDay);
    event LogPayoutTransferred(bytes32 bpKey, uint256 claimId, uint256 payoutId, uint256 amount);
    event LogError(string error, uint256 index, uint256 stored, uint256 calculated);
    event LogUnprocessableStatus(bytes32 bpKey, uint256 requestId);
    event LogPolicyExpired(bytes32 bpKey);
    event LogUnexpectedStatus(bytes32 bpKey, uint256 requestId, bytes1 status, int256 delay, address customer);

    // solhint-disable
    // Minimum observations for valid prediction
    uint256 public immutable MIN_OBSERVATIONS = 10;
    // Minimum time before departure for applying
    Seconds public MIN_TIME_BEFORE_DEPARTURE = SecondsLib.fromDays(14);
    // Maximum time before departure for applying
    Seconds public MAX_TIME_BEFORE_DEPARTURE = SecondsLib.fromDays(90);
    // Maximum duration of flight
    Seconds public MAX_FLIGHT_DURATION = SecondsLib.fromDays(2);
    // Check for delay after .. minutes after scheduled arrival
    Seconds public CHECK_OFFSET = SecondsLib.fromHours(2);
    // Max time to process claims after departure
    Seconds public LIFETIME = SecondsLib.fromDays(30);

    // uint256 public constant MIN_PREMIUM = 15 * 10 ** 18; // production
    // All amounts in cent = multiplier is 10 ** 16!
    Amount public MIN_PREMIUM;
    Amount public MAX_PREMIUM;
    Amount public MAX_PAYOUT;
    Amount public MAX_TOTAL_PAYOUT; // Maximum risk per flight is 3x max payout.

    // Maximum cumulated weighted premium per risk
    uint256 public MARGIN_PERCENT = 30;

    // ['observations','late15','late30','late45','cancelled','diverted']
    uint8[6] public WEIGHT_PATTERN = [0, 0, 0, 30, 50, 50];
    uint8 public constant MAX_WEIGHT = 50;

    // GIF V3 specifics
    NftId internal _defaultBundleNftId;

    // solhint-enable

    struct FlightRisk {
        Str carrierFlightNumber;
        Str departureYearMonthDay;
        Timestamp departureTime;
        Timestamp arrivalTime; 
        Seconds delaySeconds;
        uint8 delay; // what is this?
        Amount estimatedMaxTotalPayout;
        uint256 premiumMultiplier; // what is this? UFixed?
        uint256 weight; // what is this? UFixed?
    }

    constructor(
        address registry,
        NftId instanceNftid,
        string memory componentName,
        IAuthorization authorization
    )
    {
        address initialOwner = msg.sender;

        _initialize(
            registry,
            instanceNftid,
            componentName,
            authorization,
            initialOwner);
    }

    //--- external functions ------------------------------------------------//
    //--- unpermissioned functions ------------------------------------------//

    function createPolicy(
        address policyHolder,
        Str carrierFlightNumber,
        Str departureYearMonthDay,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premiumAmount,
        uint256[6] memory statistics
    )
        external
        virtual
        restricted()
        returns (
            NftId policyNftId,
            Amount[5] memory payoutAmounts
        )
    {
        // check application parameters and calculate payouts
        checkParameters(
            departureTime, 
            arrivalTime, 
            premiumAmount); // TODO remove? checked here and in checkAndCalculatePayouts

        (
            uint256 weight, 
            Amount sumInsuredAmount
        ) = checkAndCalculateSumInsured(
            premiumAmount, 
            statistics);

        // more checks and risk handling
        RiskId riskId = _checkAndHandleFlightRisk(
            carrierFlightNumber, 
            departureYearMonthDay, 
            departureTime, 
            arrivalTime, 
            sumInsuredAmount,
            weight);

        // effects
        policyNftId = _createApplication(
            policyHolder, 
            riskId, 
            sumInsuredAmount,
            premiumAmount,
            LIFETIME,
            _defaultBundleNftId, 
            ReferralLib.zero(), 
            abi.encode(premiumAmount)); // application data

        _createPolicy(
            policyNftId, 
            TimestampLib.zero(), // activate at 
            premiumAmount); // max premium amount

        // interactions (token transfer + callback to token holder, if contract)
        _collectPremium(
            policyNftId, 
            departureTime); // activate at
    }


    //--- owner functions ---------------------------------------------------//

    /// @dev Call after product registration with the instance, when the product token/tokenhandler is available
    function completeSetup()
        external
        virtual
        restricted()
        onlyOwner()
    {
        IERC20Metadata token = IERC20Metadata(getToken());
        uint256 tokenMultiplier = 10 ** token.decimals();

        MIN_PREMIUM = AmountLib.toAmount(15 * tokenMultiplier); 
        MAX_PREMIUM = AmountLib.toAmount(200 * tokenMultiplier); 
        MAX_PAYOUT = AmountLib.toAmount(500 * tokenMultiplier); 
        MAX_TOTAL_PAYOUT = AmountLib.toAmount(3 * MAX_PAYOUT.toInt());
    }


    function setDefaultBundle(NftId bundleNftId) external restricted() onlyOwner() { _defaultBundleNftId = bundleNftId; }
    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }


    //--- view functions ----------------------------------------------------//

    // TODO where do we need this
    function checkApplication(
        Str carrierFlightNumber,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premium
    )
        external
        virtual
        view
        returns (uint256 errors)
    {
        // Validate input parameters
        if (premium < MIN_PREMIUM) { errors = errors | (uint256(1) << 0); }
        if (premium > MAX_PREMIUM) { errors = errors | (uint256(1) << 1); }
        if (arrivalTime < departureTime) { errors = errors | (uint256(1) << 2); }
        if (arrivalTime > departureTime.addSeconds(MAX_FLIGHT_DURATION)) { errors = errors | (uint256(1) << 3); }
        if (departureTime < TimestampLib.current().addSeconds(MIN_TIME_BEFORE_DEPARTURE)) { errors = errors | (uint256(1) << 4); }
        if (departureTime > TimestampLib.current().addSeconds(MAX_TIME_BEFORE_DEPARTURE)) { errors = errors | (uint256(1) << 5); }

        (, bool exists, FlightRisk memory flightRisk) = getFlightRisk(carrierFlightNumber, departureTime, arrivalTime);
        if (exists) {
            Amount sumInsured = AmountLib.toAmount(premium.toInt() * flightRisk.premiumMultiplier);
            if (flightRisk.estimatedMaxTotalPayout + sumInsured > MAX_TOTAL_PAYOUT) {
                errors = errors | (uint256(1) << 6);
            }
        }

        return errors;
    }


    function checkParameters(
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premium
    )
        internal
        view
    {
        // solhint-disable
        require(premium >= MIN_PREMIUM, "ERROR:FDD-001:INVALID_PREMIUM");
        require(premium <= MAX_PREMIUM, "ERROR:FDD-002:INVALID_PREMIUM");
        require(arrivalTime > departureTime, "ERROR:FDD-003:ARRIVAL_BEFORE_DEPARTURE_TIME");

        // TODO decide how to handle demo mode
        require(
            arrivalTime <= departureTime.addSeconds(MAX_FLIGHT_DURATION),
            "ERROR:FDD-004:INVALID_ARRIVAL/DEPARTURE_TIME");
        require(
            TimestampLib.current() >= departureTime.subtractSeconds(MAX_TIME_BEFORE_DEPARTURE),
            "ERROR:FDD-005:INVALID_ARRIVAL/DEPARTURE_TIME");
        require(
            TimestampLib.current() <= departureTime.subtractSeconds(MIN_TIME_BEFORE_DEPARTURE),
            "ERROR:FDD-012:INVALID_ARRIVAL/DEPARTURE_TIME");
        // solhint-enable
    }


    function calculateNetPremium(
        Amount, // sumInsuredAmount: not used in this product
        RiskId, // riskId: not used in this product
        Seconds, // lifetime: not used in this product, a flight is a one time risk
        bytes memory applicationData // holds the premium amount the customer is willing to pay
    )
        external
        virtual override
        view 
        returns (Amount netPremiumAmount)
    {
        netPremiumAmount = abi.decode(applicationData, (Amount));
    }


    function checkAndCalculateSumInsured(
        Amount premium, 
        uint256[6] memory statistics
    )
        public
        view
        returns (
            uint256 weight, 
            Amount sumInsured
        )
    {
        require(premium >= MIN_PREMIUM, "ERROR:FDD-009:INVALID_PREMIUM");
        require(premium <= MAX_PREMIUM, "ERROR:FDD-010:INVALID_PREMIUM");
        require(statistics[0] >= MIN_OBSERVATIONS, "ERROR:FDD-011:LOW_OBSERVATIONS");

        weight = 0;

        for (uint256 i = 1; i < 6; i++) {
            weight += WEIGHT_PATTERN[i] * statistics[i] * 10000 / statistics[0];
            // 1% = 100 / 100% = 10,000
        }

        // To avoid div0 in the payout section, we have to make a minimal assumption on weight
        if (weight == 0) {
            weight = 100000 / statistics[0];
        }

        weight = weight * (100 + MARGIN_PERCENT) / 100;
        sumInsured = AmountLib.zero();

        for (uint256 i = 0; i < 5; i++) {
            Amount payoutAmount = AmountLib.toAmount(
                premium.toInt() * WEIGHT_PATTERN[i + 1] * 10000 / weight);

            // cap payout and update sum insured if applicable
            if (payoutAmount > MAX_PAYOUT) { payoutAmount = MAX_PAYOUT; }
            if (payoutAmount > sumInsured) { sumInsured = payoutAmount; }
        }
    }


    function getFlightRisk(
        Str carrierFlightNumber, 
        Timestamp departureTime, 
        Timestamp arrivalTime
    )
        public
        view
        returns (
            RiskId riskId,
            bool exists,
            FlightRisk memory flightRisk
        )
    {
        riskId = getRiskId(carrierFlightNumber, departureTime, arrivalTime);
        (exists, flightRisk) = getFlightRisk(riskId);
    }


    function getFlightRisk(RiskId riskId)
        public
        view
        returns (
            bool exists,
            FlightRisk memory flightRisk
        )
    {
        // check if risk exists
        InstanceReader reader = _getInstanceReader();
        exists = reader.isProductRisk(getNftId(), riskId);

        // get risk data if risk exists
        if (exists) {
            flightRisk = abi.decode(
                reader.getRiskInfo(riskId).data, (FlightRisk));
        }
    }


    function getRiskId(
        Str carrierFlightNumber, 
        Timestamp departureTime, 
        Timestamp arrivalTime
    )
        public
        virtual
        view 
        returns (RiskId riskId)
    {
        bytes32 riskKey = _getRiskKey(carrierFlightNumber, departureTime, arrivalTime);
        riskId = _getRiskId(riskKey);
    }

    //--- internal functions ------------------------------------------------//

    function _checkAndHandleFlightRisk(
        Str carrierFlightNumber,
        Str departureYearMonthDay,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount sumInsuredAmount,
        uint256 weight
    )
        internal
        virtual
        returns (RiskId riskId)
    {
        bool exists;
        FlightRisk memory flightRisk;
        (riskId, exists, flightRisk) = getFlightRisk(carrierFlightNumber, departureTime, arrivalTime);

        // first flight for this risk
        if (!exists) {
            uint256 multiplier = (uint256(MAX_WEIGHT) * 10000) / weight;

            flightRisk = FlightRisk({
                carrierFlightNumber: carrierFlightNumber,
                departureYearMonthDay: departureYearMonthDay,
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                delaySeconds: SecondsLib.zero(),
                delay: 0, // TODO what is this? rename?
                estimatedMaxTotalPayout: sumInsuredAmount,
                premiumMultiplier: multiplier,
                weight: weight
            });

            // create new risk including 1st sum insured amount
            bytes32 riskKey = _getRiskKey(carrierFlightNumber, departureTime, arrivalTime);
            _createRisk(riskKey, abi.encode(flightRisk));

        // additional flights for this risk
        } else {
            // check for cluster risk: additional sum insured amount must not exceed MAX_TOTAL_PAYOUT
            require (
                flightRisk.estimatedMaxTotalPayout + sumInsuredAmount <= MAX_TOTAL_PAYOUT,
                "ERROR:FDD-006:CLUSTER_RISK"
            );

            // update existing risk with additional sum insured amount
            flightRisk.estimatedMaxTotalPayout = flightRisk.estimatedMaxTotalPayout + sumInsuredAmount;
            _updateRisk(riskId, abi.encode(flightRisk));
        }
    }

    function _getRiskKey(
        Str carrierFlightNumber, 
        Timestamp departureTime, 
        Timestamp arrivalTime
    )
        internal
        pure
        returns (bytes32 riskKey)
    {
        return keccak256(abi.encode(carrierFlightNumber, departureTime, arrivalTime));
    }


    function _getRiskId(bytes32 riskKey) internal view returns (RiskId riskId) {
        return RiskIdLib.toRiskId(getNftId(), riskKey);
    }


    function _initialize(
        address registry,
        NftId instanceNftId,
        string memory componentName,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicProduct(
            registry,
            instanceNftId,
            componentName,
            IComponents.ProductInfo({
                isProcessingFundedClaims: false,
                isInterceptingPolicyTransfers: false,
                hasDistribution: false,
                expectedNumberOfOracles: 0,
                numberOfOracles: 0,
                poolNftId: NftIdLib.zero(),
                distributionNftId: NftIdLib.zero(),
                oracleNftId: new NftId[](0)
            }), 
            IComponents.FeeInfo({
                productFee: FeeLib.zero(),
                processingFee: FeeLib.zero(),
                distributionFee: FeeLib.zero(),
                minDistributionOwnerFee: FeeLib.zero(),
                poolFee: FeeLib.zero(),
                stakingFee: FeeLib.zero(),
                performanceFee: FeeLib.zero()
            }),
            authorization,
            initialOwner);  // number of oracles
    }
}