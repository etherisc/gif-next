// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
import {IPolicy} from "../../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {Component} from "../../shared/Component.sol";
import {FeeLib} from "../../type/Fee.sol";
import {FlightLib} from "./FlightLib.sol";
import {FlightMessageVerifier} from "./FlightMessageVerifier.sol";
import {FlightOracle} from "./FlightOracle.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {Product} from "../../product/Product.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {RequestId} from "../../type/RequestId.sol";
import {Seconds, SecondsLib} from "../../type/Seconds.sol";
import {Str, StrLib} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";


/// @dev FlightProduct implements the flight delay product.
contract FlightProduct is
    Product
{

    event LogFlightPolicyPurchased(NftId policyNftId, string flightData, Amount premiumAmount);
    event LogFlightPolicyClosed(NftId policyNftId, Amount payoutAmount);

    event LogFlightStatusProcessed(RequestId requestId, RiskId riskId, bytes1 status, int256 delayMinutes, uint8 payoutOption);
    event LogFlightPoliciesProcessed(RiskId riskId, uint8 payoutOption, uint256 policiesProcessed, uint256 policiesRemaining);

    // solhint-disable
    Amount public MIN_PREMIUM;
    Amount public MAX_PREMIUM;
    Amount public MAX_PAYOUT;
    Amount public MAX_TOTAL_PAYOUT; // Maximum risk per flight/risk

    // Minimum time before departure for applying
    Seconds public MIN_TIME_BEFORE_DEPARTURE;
    // Maximum time before departure for applying
    Seconds public MAX_TIME_BEFORE_DEPARTURE;
    // Maximum duration of flight
    Seconds public MAX_FLIGHT_DURATION;
    // Max time to process claims after departure
    Seconds public LIFETIME;

    // ['observations','late15','late30','late45','cancelled','diverted']
    // no payouts for delays of 30' or less
    uint8[6] public WEIGHT_PATTERN;
    // Minimum number of observations for valid prediction/premium calculation
    uint256 public MIN_OBSERVATIONS;
    // Maximum cumulated weighted premium per risk
    uint256 public MARGIN_PERCENT;
    // Maximum number of policies to process in one callback
    uint8 public MAX_POLICIES_TO_PROCESS;
    // solhint-enable

    bool internal _testMode;

    mapping(RiskId riskId => RequestId requestId) internal _requests;

    // GIF V3 specifics
    NftId internal _defaultBundleNftId;
    NftId internal _oracleNftId;


    struct FlightRisk {
        Str flightData; // example: "LX 180 ZRH BKK 20241104"
        Timestamp departureTime;
        // this field contains static data required by the frontend and is not directly used by the product
        string departureTimeLocal; // example "2024-10-14T10:10:00.000 Asia/Seoul"
        Timestamp arrivalTime; 
        // this field contains static data required by the frontend and is not directly used by the product
        string arrivalTimeLocal; // example "2024-10-14T10:10:00.000 Asia/Seoul"
        Amount sumOfSumInsuredAmounts;
        bytes1 status; // 'L'ate, 'C'ancelled, 'D'iverted, ...
        int256 delayMinutes;
        uint8 payoutOption;
        Timestamp statusUpdatedAt;
    }


    struct ApplicationData {
        string flightData;
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
        NftId instanceNftId,
        string memory componentName,
        IAuthorization authorization
    )
    {
        address initialOwner = msg.sender;

        _initialize(
            registry,
            instanceNftId,
            componentName,
            authorization,
            initialOwner);
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
        _processPermit(permit);

        // create policy
        address policyHolder = permit.owner;
        (
            riskId,
            policyNftId
        ) = _createPolicy(
            policyHolder,
            StrLib.toStr(application.flightData),
            application.departureTime,
            application.departureTimeLocal,
            application.arrivalTime,
            application.arrivalTimeLocal,
            application.premiumAmount,
            application.statistics);
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
            response.delayMinutes);
    }


    function resendRequest(RequestId requestId)
        external
        virtual
        restricted()
    {
        _resendRequest(requestId);
    }


    /// @dev Manual fallback function for product owner.
    function processPayoutsAndClosePolicies(
        RiskId riskId, 
        uint8 maxPoliciesToProcess
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        _processPayoutsAndClosePolicies(
            riskId, 
            maxPoliciesToProcess);
    }


    //--- owner functions ---------------------------------------------------//

    /// @dev Call after product registration with the instance
    /// when the product token/tokenhandler is available
    function setConstants(
        Amount minPremium,
        Amount maxPremium,
        Amount maxPayout,
        Amount maxTotalPayout,
        Seconds minTimeBeforeDeparture,
        Seconds maxTimeBeforeDeparture,
        uint8 maxPoliciesToProcess
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        MIN_PREMIUM = minPremium; 
        MAX_PREMIUM = maxPremium; 
        MAX_PAYOUT = maxPayout; 
        MAX_TOTAL_PAYOUT = maxTotalPayout;

        MIN_TIME_BEFORE_DEPARTURE = minTimeBeforeDeparture;
        MAX_TIME_BEFORE_DEPARTURE = maxTimeBeforeDeparture;
        MAX_POLICIES_TO_PROCESS = maxPoliciesToProcess;
    }

    function setDefaultBundle(NftId bundleNftId) external restricted() onlyOwner() { _defaultBundleNftId = bundleNftId; }
    function setTestMode(bool testMode) external restricted() onlyOwner() { _testMode = testMode; }

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


    function getOracleNftId() public view returns (NftId oracleNftId) { return _oracleNftId; }
    function isTestMode() public view returns (bool) { return _testMode; }


    function getFlightRisk(
        RiskId riskId,
        bool requireRiskExists
    )
        public
        view
        returns (
            bool exists,
            FlightRisk memory flightRisk
        )
    {
        (exists, flightRisk) = FlightLib.getFlightRisk(
            _getInstanceReader(), 
            getNftId(), 
            riskId, 
            requireRiskExists);
    }

    function getRequestForRisk(RiskId riskId) public view returns (RequestId requestId) { return _requests[riskId]; }
    function decodeFlightRiskData(bytes memory data) public pure returns (FlightRisk memory) { return abi.decode(data, (FlightRisk)); }

    //--- internal functions ------------------------------------------------//


    function _processPermit(
        PermitData memory permit
    )
        internal
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


    function _createPolicy(
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
        // checks
        // disabled for now - using rbac for security
        FlightLib.checkApplicationData(
            this,
            flightData,
            departureTime,
            arrivalTime,
            premiumAmount);

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

        // send oracle request for for new risk to obtain flight status (interacts with flight oracle contract)
        if (_requests[riskId].eqz()) {
            _requests[riskId] = _sendRequest(
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

        emit LogFlightPolicyPurchased(policyNftId, flightData.toString(), premiumAmount);
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

        FlightLib.checkClusterRisk(
            flightRisk.sumOfSumInsuredAmounts, 
            sumInsuredAmount, 
            MAX_TOTAL_PAYOUT);

        // update existing risk with additional sum insured amount
        flightRisk.sumOfSumInsuredAmounts = flightRisk.sumOfSumInsuredAmounts + sumInsuredAmount;
        _updateRisk(riskId, abi.encode(flightRisk));
    }


    function _processFlightStatus(
        RequestId requestId,
        RiskId riskId, 
        bytes1 status, 
        int256 delayMinutes
    )
        internal
        virtual
    {
        // check risk exists
        (, FlightRisk memory flightRisk) = getFlightRisk(riskId, true);

        // update status, if not yet set
        if (flightRisk.statusUpdatedAt.eqz()) {
            flightRisk.statusUpdatedAt = TimestampLib.current();
            flightRisk.status = status;
            flightRisk.delayMinutes = delayMinutes;
            flightRisk.payoutOption = FlightLib.checkAndGetPayoutOption(
                requestId, riskId, status, delayMinutes);

            _updateRisk(riskId, abi.encode(flightRisk));
        }

        (,, uint8 payoutOption) = _processPayoutsAndClosePolicies(
            riskId, 
            MAX_POLICIES_TO_PROCESS);

        // logging
        emit LogFlightStatusProcessed(requestId, riskId, status, delayMinutes, payoutOption);
    }


    function _processPayoutsAndClosePolicies(
        RiskId riskId, 
        uint8 maxPoliciesToProcess
    )
        internal
        virtual
        returns (
            bool riskExists, 
            bool statusAvailable,
            uint8 payoutOption
        )
    {
        // determine numbers of policies to process
        InstanceReader reader = _getInstanceReader();
        (riskExists, statusAvailable, payoutOption) = FlightLib.getPayoutOption(reader, getNftId(), riskId);

        // return with default values if risk does not exist or status is not yet available
        if (!riskExists || !statusAvailable) {
            return (riskExists, statusAvailable, payoutOption);
        }

        uint256 policiesToProcess = reader.policiesForRisk(riskId);
        uint256 policiesProcessed = policiesToProcess < maxPoliciesToProcess ? policiesToProcess : maxPoliciesToProcess;

        // assemble array with policies to process
        NftId [] memory policies = new NftId[](policiesProcessed);
        for (uint256 i = 0; i < policiesProcessed; i++) {
            policies[i] = reader.getPolicyForRisk(riskId, i);
        }

        // go through policies
        for (uint256 i = 0; i < policiesProcessed; i++) {
            NftId policyNftId = policies[i];
            Amount payoutAmount = FlightLib.getPayoutAmount(
                reader.getPolicyInfo(policyNftId).applicationData, 
                payoutOption);

            // create claim/payout (if applicable)
            _resolvePayout(
                policyNftId, 
                payoutAmount); 

            // expire and close policy
            _expire(policyNftId, TimestampLib.current());
            _close(policyNftId);

            emit LogFlightPolicyClosed(policyNftId, payoutAmount);
        }

        // logging
        emit LogFlightPoliciesProcessed(riskId, payoutOption, policiesProcessed, policiesToProcess - policiesProcessed);
    }


    function _resolvePayout(
        NftId policyNftId,
        Amount payoutAmount
    )
        internal
        virtual
    {
        // no action if no payout
        if (payoutAmount.eqz()) {
            return;
        }

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
        initializer()
    {
        __Product_init(
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

        MAX_FLIGHT_DURATION = SecondsLib.fromDays(2);
        LIFETIME = SecondsLib.fromDays(30);
        WEIGHT_PATTERN = [0, 0, 0, 30, 50, 50];
        MIN_OBSERVATIONS = 10;
        MARGIN_PERCENT = 30;
    }
}