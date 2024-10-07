// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {FeeLib} from "../../type/Fee.sol";
import {FlightLib} from "./FlightLib.sol";
import {FlightMessageVerifier} from "./FlightMessageVerifier.sol";
import {FlightOracle} from "./FlightOracle.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {RequestId} from "../../type/RequestId.sol";
import {Seconds, SecondsLib} from "../../type/Seconds.sol";
import {Str} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";


/// @dev FlightProduct implements the flight delay product.
contract FlightProduct is
    BasicProduct
{

    event LogRequestFlightRatings(uint256 requestId, bytes32 carrierFlightNumber, uint256 departureTime, uint256 arrivalTime, bytes32 riskId);
    event LogRequestFlightStatus(uint256 requestId, uint256 arrivalTime, bytes32 carrierFlightNumber, bytes32 departureYearMonthDay);
    event LogPayoutTransferred(bytes32 bpKey, uint256 claimId, uint256 payoutId, uint256 amount);
    event LogFlightStatusProcessed(RequestId requestId, RiskId riskId, bytes1 status, int256 delayMinutes, uint8 payoutOption);

    // TODO convert error logs to custom errors
    event LogError(string error, uint256 index, uint256 stored, uint256 calculated);
    event LogPolicyExpired(bytes32 bpKey);

    event LogErrorRiskInvalid(RequestId requestId, RiskId riskId);
    event LogErrorUnprocessableStatus(RequestId requestId, RiskId riskId, bytes1 status);
    event LogErrorUnexpectedStatus(RequestId requestId, RiskId riskId, bytes1 status, int256 delayMinutes);

    error ErrorApplicationDataSignatureMismatch(address expectedSigner, address actualSigner);
    error ErrorFlightProductClusterRisk(Amount totalSumInsured, Amount maxTotalPayout);
    error ErrorFlightProductPremiumAmountTooSmall(Amount premiumAmount, Amount minPremium);
    error ErrorFlightProductPremiumAmountTooLarge(Amount premiumAmount, Amount maxPremium);
    error ErrorFlightProductArrivalBeforeDepartureTime(Timestamp departureTime, Timestamp arrivalTime);
    error ErrorFlightProductArrivalAfterMaxFlightDuration(Timestamp arrivalTime, Timestamp maxArrivalTime, Seconds maxDuration);
    error ErrorFlightProductDepartureBeforeMinTimeBeforeDeparture(Timestamp departureTime, Timestamp now, Seconds minTimeBeforeDeparture);
    error ErrorFlightProductDepartureAfterMaxTimeBeforeDeparture(Timestamp departureTime, Timestamp now, Seconds maxTimeBeforeDeparture);
    error ErrorFlightProductNotEnoughObservations(uint256 observations, uint256 minObservations);

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
    Seconds public CHECK_OFFSET = SecondsLib.fromHours(1);
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

    // Maximum number of policies to process in one callback
    uint8 public MAX_POLICIES_TO_PROCESS = 5;

    // ['observations','late15','late30','late45','cancelled','diverted']
    // no payouts for delays of 30' or less
    uint8[6] public WEIGHT_PATTERN = [0, 0, 0, 30, 50, 50];
    uint8 public constant MAX_WEIGHT = 50;

    // GIF V3 specifics
    NftId internal _defaultBundleNftId;

    // TODO add product (base contract) functions
    // - getOracleNftId(idx)
    // - getDistributionNftId() 
    // - getPoolNftId()
    NftId internal _oracleNftId; // TODO refactor to getOracleNftId(0)
    // solhint-enable

    FlightMessageVerifier internal _flightMessageVerifier;


    struct FlightRisk {
        Str flightData; // example: "LX 180 ZRH BKK 20241104"
        Timestamp departureTime;
        // this field contains static data required by the frontend and is not directly used by the product
        string departureTimeLocal; // example "2024-10-14T10:10:00.000 Asia/Seoul"
        Timestamp arrivalTime; 
        // this field contains static data required by the frontend and is not directly used by the product
        string arrivalTimeLocal; // example "2024-10-14T10:10:00.000 Asia/Seoul"
        Amount sumOfSumInsuredAmounts;
        // uint256 premiumMultiplier; // what is this? UFixed?
        // uint256 weight; // what is this? UFixed?
        bytes1 status; // 'L'ate, 'C'ancelled, 'D'iverted, ...
        int256 delayMinutes;
    }

    struct ApplicationData {
        Str flightData;
        Timestamp departureTime;
        string departureTimeLocal;
        Timestamp arrivalTime;
        string arrivalTimeLocal;
        Amount premiumAmount;
        uint256[6] statistics;
    }

    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }


    constructor(
        address registry,
        NftId instanceNftid,
        string memory componentName,
        IAuthorization authorization,
        FlightMessageVerifier messageVerifier
    )
    {
        address initialOwner = msg.sender;

        _initialize(
            registry,
            instanceNftid,
            componentName,
            authorization,
            initialOwner);

        _flightMessageVerifier = messageVerifier;
    }

    //--- external functions ------------------------------------------------//
    //--- unpermissioned functions ------------------------------------------//

    function setOracleNftId()
        external
    {
        _oracleNftId = _getInstanceReader().getProductInfo(
            getNftId()).oracleNftId[0];
    }

    function calculatePayoutAmounts(
        FlightProduct flightProduct,
        Amount premium, 
        uint256[6] memory statistics
    ) 
        external
        view
        returns (
            uint256 weight, 
            Amount[5] memory payoutAmounts,
            Amount sumInsuredAmount // simply the max of payoutAmounts 
        ) 
    {
        return FlightLib.calculatePayoutAmounts(
            flightProduct,
            premium,
            statistics);
    }

    /// @dev Creates a policy using a permit for the policy holder.
    /// The policy holder is defined as the owner parameter of the permit data.
    /// NOTE: This function makes the assumption that the product token
    /// supports permits. This assumption is not verfied.
    function createPolicyWithPermit(
        PermitData memory permit,
        ApplicationData memory application
    )
        external
        virtual
        restricted()
        returns (
            RiskId riskId,
            NftId policyNftId
        )
    {
        // process permit data
        processPermit(permit);

        // create policy
        address policyHolder = permit.owner;
        (
            riskId,
            policyNftId
        ) = createPolicy(
            policyHolder,
            application.flightData,
            application.departureTime,
            application.departureTimeLocal,
            application.arrivalTime,
            application.arrivalTimeLocal,
            application.premiumAmount,
            application.statistics);
            // application.v,
            // application.r,
            // application.s);
    }


    function processPermit(
        PermitData memory permit
    )
        public
        virtual
        restricted()
    {
        address tokenAddress = address(getToken());

        // process permit data
        ERC20Permit(tokenAddress).permit(
            permit.owner, 
            permit.spender, 
            permit.value, 
            permit.deadline, 
            permit.v, 
            permit.r, 
            permit.s); 
    }


    function createPolicy(
        address policyHolder,
        Str flightData, 
        Timestamp departureTime,
        string memory departureTimeLocal,
        Timestamp arrivalTime,
        string memory arrivalTimeLocal,
        Amount premiumAmount,
        uint256[6] memory statistics
        // signature fields
        // uint8 v, 
        // bytes32 r, 
        // bytes32 s
    )
        public
        virtual
        restricted()
        returns (
            RiskId riskId,
            NftId policyNftId
        )
    {
        // checks
        // disabled for now - using rbac for security
        FlightLib.checkApplicationDataAndSignature(
            this,
            flightData,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics);
            // v, r, s);

        (riskId, policyNftId) = _prepareApplication(
            policyHolder, 
            flightData,
            departureTime,
            departureTimeLocal,
            arrivalTime,
            arrivalTimeLocal,
            premiumAmount,
            statistics);

        _createPolicy(
            policyNftId, 
            TimestampLib.zero(), // do not ativate yet 
            premiumAmount); // max premium amount

        // interactions (token transfer + callback to token holder, if contract)
        _collectPremium(
            policyNftId, 
            departureTime); // activate at scheduled departure time of flight

        // send oracle request for flight status (interacts with flight oracle contract)
        _sendRequest(
            _oracleNftId, 
            abi.encode(
                FlightOracle.FlightStatusRequest(
                    riskId,
                    flightData,
                    departureTime)),
            // allow up to 30 days to process the claim
            arrivalTime.addSeconds(SecondsLib.fromDays(30)), 
            "flightStatusCallback");
    }


    function _prepareApplication(
        address policyHolder,
        Str flightData, 
        Timestamp departureTime,
        string memory departureTimeLocal,
        Timestamp arrivalTime,
        string memory arrivalTimeLocal,
        Amount premiumAmount,
        uint256[6] memory statistics
    )
        internal
        virtual
        returns (
            RiskId riskId,
            NftId policyNftId
        )
    {
        Amount[5] memory payoutAmounts;
        Amount sumInsuredAmount;

        (
            riskId, 
            payoutAmounts,
            sumInsuredAmount
        ) = _createRiskAndPayoutAmounts(
            flightData,
            departureTime,
            departureTimeLocal,
            arrivalTime,
            arrivalTimeLocal,
            premiumAmount,
            statistics);

        policyNftId = _createApplication(
            policyHolder, 
            riskId, 
            sumInsuredAmount,
            premiumAmount,
            LIFETIME,
            _defaultBundleNftId, 
            ReferralLib.zero(), 
            abi.encode(
                premiumAmount,
                payoutAmounts)); // application data
    }


    /// @dev Callback for flight status oracle.
    /// Function may only be alled by oracle service.
    function flightStatusCallback(
        RequestId requestId,
        bytes memory responseData
    )
        external
        virtual
        restricted()
    {
        FlightOracle.FlightStatusResponse memory response = abi.decode(
            responseData, (FlightOracle.FlightStatusResponse));

        _processFlightStatus(
            requestId, 
            response.riskId, 
            response.status, 
            response.delayMinutes, 
            MAX_POLICIES_TO_PROCESS);
    }


    /// @dev Manual fallback function for product owner.
    function processFlightStatus(
        RequestId requestId,
        RiskId riskId, 
        bytes1 status, 
        int256 delayMinutes,
        uint8 maxPoliciesToProcess
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        _processFlightStatus(
            requestId, 
            riskId, 
            status, 
            delayMinutes, 
            maxPoliciesToProcess);
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
        (netPremiumAmount, ) = abi.decode(applicationData, (Amount, Amount[5]));
    }


    function getFlightMessageVerifier()
        external
        view
        returns (FlightMessageVerifier)
    {
        return _flightMessageVerifier;
    }


    function getOracleNftId()
        public
        view
        returns (NftId oracleNftId)
    { 
        return _oracleNftId;
    }

    function decodeFlightRiskData(bytes memory data) external pure returns (FlightRisk memory) {
        return abi.decode(data, (FlightRisk));
    }

    //--- internal functions ------------------------------------------------//


    function _createRiskAndPayoutAmounts(
        Str flightData, 
        Timestamp departureTime,
        string memory departureTimeLocal,
        Timestamp arrivalTime,
        string memory arrivalTimeLocal,
        Amount premiumAmount,
        uint256[6] memory statistics
    )
        internal
        virtual
        returns (
            RiskId riskId,
            Amount[5] memory payoutAmounts,
            Amount sumInsuredAmount
        )
    {
        uint256 weight;

        (
            weight, 
            payoutAmounts,            
            sumInsuredAmount
        ) = FlightLib.calculatePayoutAmounts(
            this,
            premiumAmount, 
            statistics);

        riskId = _checkAndUpdateFlightRisk(
            flightData,
            departureTime,
            departureTimeLocal,
            arrivalTime,
            arrivalTimeLocal,
            sumInsuredAmount,
            weight);
    }


    function _checkAndUpdateFlightRisk(
        Str flightData,
        Timestamp departureTime,
        string memory departureTimeLocal,
        Timestamp arrivalTime,
        string memory arrivalTimeLocal,
        Amount sumInsuredAmount,
        uint256 weight
    )
        internal
        virtual
        returns (RiskId riskId)
    {
        bool exists;
        FlightRisk memory flightRisk;
        (riskId, exists, flightRisk) = FlightLib.getFlightRisk(
            _getInstanceReader(), 
            getNftId(), 
            flightData, 
            departureTime, 
            departureTimeLocal,
            arrivalTime,
            arrivalTimeLocal);

        // create risk, if new
        if (!exists) {
            bytes32 riskKey = FlightLib.getRiskKey(flightData);
            _createRisk(riskKey, abi.encode(flightRisk));
        }

        // check for cluster risk: additional sum insured amount must not exceed MAX_TOTAL_PAYOUT
        if (flightRisk.sumOfSumInsuredAmounts + sumInsuredAmount > MAX_TOTAL_PAYOUT) {
            revert ErrorFlightProductClusterRisk(flightRisk.sumOfSumInsuredAmounts + sumInsuredAmount, MAX_TOTAL_PAYOUT);
        }

        // update existing risk with additional sum insured amount
        flightRisk.sumOfSumInsuredAmounts = flightRisk.sumOfSumInsuredAmounts + sumInsuredAmount;
        _updateRisk(riskId, abi.encode(flightRisk));
    }


    function _processFlightStatus(
        RequestId requestId,
        RiskId riskId, 
        bytes1 status, 
        int256 delayMinutes,
        uint8 maxPoliciesToProcess
    )
        internal
        virtual
    {
        // check risk exists
        InstanceReader reader = _getInstanceReader();
        (
            bool exists,
            FlightRisk memory flightRisk
        ) = FlightLib.getFlightRisk(reader, getNftId(), riskId);

        if (!exists) {
            emit LogErrorRiskInvalid(requestId, riskId);
            return;
        }

        uint8 payoutOption = FlightLib.checkAndGetPayoutOption(
            requestId, riskId, status, delayMinutes);

        _processPayoutsAndClosePolicies(
            riskId, 
            payoutOption, 
            maxPoliciesToProcess);

        // logging
        emit LogFlightStatusProcessed(requestId, riskId, status, delayMinutes, payoutOption);
    }


    // REMARK caller responsible to check that risk exists.
    function _processPayoutsAndClosePolicies(
        RiskId riskId, 
        uint8 payoutOption,
        uint8 maxPoliciesToProcess
    )
        internal
        virtual
    {
        // determine numbers of policies to process
        InstanceReader reader = _getInstanceReader();
        uint256 policiesToProcess = reader.policiesForRisk(riskId);
        policiesToProcess = policiesToProcess < maxPoliciesToProcess ? policiesToProcess : maxPoliciesToProcess;

        // go trough policies
        for (uint256 i = 0; i < policiesToProcess; i++) {
            NftId policyNftId = reader.getPolicyForRisk(riskId, i);

            // create payout (if any)
            if (payoutOption < type(uint8).max) { 
                bytes memory applicationData = reader.getPolicyInfo(
                    policyNftId).applicationData;

                _resolvePayout(
                    policyNftId, 
                    FlightLib.getPayoutAmount(
                        applicationData, 
                        payoutOption)); 
            }

            // expire and close policy
            _expire(policyNftId, TimestampLib.current());
            _close(policyNftId);
        }
    }


    function _resolvePayout(
        NftId policyNftId,
        Amount payoutAmount
    )
        internal
        virtual
    {
        // create confirmed claim
        ClaimId claimId = _submitClaim(policyNftId, payoutAmount, "");
        _confirmClaim(policyNftId, claimId, payoutAmount, "");

        // create and execute payout
        PayoutId payoutId = _createPayout(policyNftId, claimId, payoutAmount, "");
        _processPayout(policyNftId, payoutId);
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
                expectedNumberOfOracles: 1,
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