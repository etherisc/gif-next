// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";

import {Amount, AmountLib} from "../../type/Amount.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {FeeLib} from "../../type/Fee.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {Location, LocationLib} from "./Location.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {Product} from "../../product/Product.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId} from "../../type/RiskId.sol";
import {RequestId} from "../../type/RequestId.sol";
import {Seconds, SecondsLib} from "../../type/Seconds.sol";
import {Str} from "../../type/String.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../type/UFixed.sol";


/// @dev CropProduct implements the crop insurance product.
contract CropProduct is
    Product
{

    // Custom errors
    error ErrorInvalidId(string id);
    error ErrorRecordAlreadyExists(string id);

    error ErrorInvalidYear(uint16 year);
    error ErrorInvalidSeasonStart(string seasonStart);
    error ErrorInvalidSeasonEnd(string seasonEnd);
    error ErrorInvalidSeasonDays(uint16 seasonDays);

    error ErrorInvalidSeasonEndAt(Timestamp seasonEndAt);

    error ErrorInvalidSeasonId(string seasonId);
    error ErrorInvalidLocation(string locationId);
    error ErrorInvalidCrop(string crop);

    error ErrorInvalidPolicyHolder(); 
    error ErrorInvalidRiskId(RiskId riskId);
    error ErrorInvalidActivateAt(Timestamp activateAt);
    error ErrorInvalidSumInsured(Amount sumInsuredAmount);
    error ErrorInvalidPremium(Amount premiumAmount);

    // solhint-disable var-name-mixedcase
    Amount public MIN_PREMIUM;
    Amount public MAX_PREMIUM;
    Amount public MIN_SUM_INSURED;
    Amount public MAX_SUM_INSURED;
    uint8 public MAX_POLICIES_TO_PROCESS = 1;
    // solhint-enable var-name-mixedcase

    // Crop insurance specifics
    uint16 public constant GRACE_PERIOD_DAYS = 60;

    struct Season {
        uint16 year;
        Str name;
        Str seasonStart; // ISO 8601 date
        Str seasonEnd; // ISO 8601 date
        uint16 seasonDays;
    }

    struct CropRisk {
        Str seasonId;
        Str locationId;
        Str crop;
        Timestamp seasonEndAt;
        UFixed payoutFactor;
    }

    // Seasons
    mapping (Str seasonId => Season season) internal _season;
    Str [] internal _seasons;

    // Locations
    mapping(Str locationId => Location location) internal _location;

    // Crop names
    mapping(Str cropName => bool isValid) internal _validCrop;
    Str [] internal _crops;

    mapping(Str id => RiskId riskId) internal _riskId;
    mapping(RiskId riskId => RequestId requestId) internal _requests;

    // GIF V3 specifics
    NftId internal _defaultBundleNftId;
    NftId internal _oracleNftId;


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


    //--- external risk relatee functions -----------------------------------//

    function createSeason(
        Str seasonId,
        uint16 year,
        Str name,
        Str seasonStart, // ISO 8601 date, eg "2025-02-18"
        Str seasonEnd,
        uint16 seasonDays
    )
        external
        restricted()
    {
        // validate input
        if (seasonId.length() == 0) { revert ErrorInvalidId(seasonId.toString()); }
        if (_season[seasonId].year > 0) { revert ErrorRecordAlreadyExists(seasonId.toString()); }
        if (year < 2023 || year > 2035 ) { revert ErrorInvalidYear(year); }
        if (seasonStart.length() != 10 ) { revert ErrorInvalidSeasonStart(seasonStart.toString()); }
        if (seasonEnd.length() != 10 ) { revert ErrorInvalidSeasonEnd(seasonEnd.toString()); }
        if (seasonDays < 50 || seasonDays > 250 ) { revert ErrorInvalidSeasonDays(seasonDays); }

        _seasons.push(seasonId);
        _season[seasonId] = Season({
            year: year,
            name: name,
            seasonStart: seasonStart,
            seasonEnd: seasonEnd,
            seasonDays: seasonDays
        });
    }

    function createLocation(
        Str locationId,
        int32 latitude,
        int32 longitude
    )
        external
        restricted()
        returns (Location location)
    {
        // validate input
        if (locationId.length() == 0) { revert ErrorInvalidId(locationId.toString()); }
        // TODO add function location.isUndefined()
        // if (!_location[locationId].isUndefined()) { revert ErrorRecordAlreadyExists(locationId.toString()); }

        location = LocationLib.toLocation(latitude, longitude);
        _location[locationId] = location;
    }

    function createCrop(Str cropName) external restricted() {
        if (cropName.length() == 0) { revert ErrorInvalidId(cropName.toString()); }
        if (_validCrop[cropName]) { revert ErrorRecordAlreadyExists(cropName.toString()); }

        _crops.push(cropName);
        _validCrop[cropName] = true;
    }

    function createRisk(
        Str id,
        Str seasonId,
        Str locationId,
        Str crop,
        Timestamp seasonEndAt
    )
        external
        restricted()
        returns (RiskId riskId)
    {
        // validate input
        if (id.length() == 0) { revert ErrorInvalidId(id.toString()); }
        if (_season[seasonId].year == 0) { revert ErrorInvalidSeasonId(seasonId.toString()); }
        // TODO add function location.isUndefined()
        // if (_locations[locationId].isUndefined()) { revert ErrorInvalidLocation(locationId.toString()); }
        if (!_validCrop[crop]) { revert ErrorInvalidCrop(crop.toString()); }
        if (seasonEndAt < TimestampLib.current()) { revert ErrorInvalidSeasonEndAt(seasonEndAt); }

        // create risk, if new
        bytes32 riskKey = keccak256(abi.encode(id));
        CropRisk memory cropRisk = CropRisk({
            seasonId: seasonId,
            locationId: locationId,
            crop: crop,
            seasonEndAt: seasonEndAt,
            payoutFactor: UFixedLib.zero()
        });

        riskId = _createRisk(riskKey, abi.encode(cropRisk));
        _riskId[id] = riskId;
    }


    function updatePayoutFactor(
        RiskId riskId,
        UFixed payoutFactor
    )
        external
        restricted()
    {
        (bool exists, CropRisk memory cropRisk) = getRisk(riskId);
        if (!exists) { revert ErrorInvalidRiskId(riskId); }

        cropRisk.payoutFactor = payoutFactor;
        _updateRisk(riskId, abi.encode(cropRisk));
    }

    //--- external policy related functions ---------------------------------//

    /// @dev Creates a policy.
    function createPolicy(
        address policyHolder,
        RiskId riskId,
        Timestamp activateAt,
        Amount sumInsuredAmount,
        Amount premiumAmount
    )
        external
        virtual
        restricted()
        returns (NftId policyNftId)
    {
        // validate input
        if (policyHolder == address(0)) { revert ErrorInvalidPolicyHolder(); }

        (bool exists, CropRisk memory cropRisk) = getRisk(riskId);
        if (!exists) { revert ErrorInvalidRiskId(riskId); }

        if (activateAt < TimestampLib.current()) { revert ErrorInvalidActivateAt(activateAt); }
        if (activateAt > cropRisk.seasonEndAt) { revert ErrorInvalidActivateAt(activateAt); }
        if (sumInsuredAmount < MIN_SUM_INSURED || sumInsuredAmount > MAX_SUM_INSURED) { revert ErrorInvalidSumInsured(sumInsuredAmount); }
        if (premiumAmount < MIN_PREMIUM || premiumAmount > MAX_PREMIUM) { revert ErrorInvalidPremium(premiumAmount); }

        // calculate policy lifetime
        uint96 seasonDays = _season[cropRisk.seasonId].seasonDays;
        Seconds lifetime = SecondsLib.toSeconds((seasonDays + GRACE_PERIOD_DAYS) * 24 * 3600);

        // create application
        policyNftId = _createApplication(
            policyHolder, 
            riskId, 
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            _defaultBundleNftId, 
            ReferralLib.zero(), 
            ""); // application data

        // underwrite and activate policy
        _createPolicy(
            policyNftId, 
            activateAt, 
            premiumAmount); // max premium amount

        _collectPremium(
            policyNftId, 
            TimestampLib.zero()); // keep activation timestamp
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


    function resendResponse(RequestId requestId)
        external
        virtual
        restricted()
    {
        _resendResponse(requestId);
    }

    /// @dev Call after product registration with the instance
    /// when the product token/tokenhandler is available
    function setConstants(
        Amount minPremium,
        Amount maxPremium,
        Amount minSumInsured,
        Amount maxSumInsured,
        uint8 maxPoliciesToProcess
    )
        external
        virtual
        restricted()
        onlyOwner()
    {
        MIN_PREMIUM = minPremium; 
        MAX_PREMIUM = maxPremium; 
        MIN_SUM_INSURED = minSumInsured;
        MAX_SUM_INSURED = maxSumInsured;
        MAX_POLICIES_TO_PROCESS = maxPoliciesToProcess;
    }

    function setDefaultBundle(NftId bundleNftId) external restricted() onlyOwner() { _defaultBundleNftId = bundleNftId; }

    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }

    //--- unpermissioned functions ------------------------------------------//

    function setOracleNftId()
        external
    {
        _oracleNftId = _getInstanceReader().getProductInfo(
            getNftId()).oracleNftId[0];
    }

    //--- view functions ----------------------------------------------------//

    function getSeason(Str seasonId) public view returns (Season memory season) { return _season[seasonId]; }
    function getLocation(Str locationId) public view returns (Location location) { return _location[locationId]; }

    function seasons() public view returns (Str [] memory) { return _seasons; }
    function crops() public view returns (Str [] memory) { return _crops; }

    function getRisk(RiskId riskId)
        public
        view
        returns (
            bool exists,
            CropRisk memory cropRisk
        )
    {
        // check if risk exists
        InstanceReader reader = _getInstanceReader();
        exists = reader.isProductRisk(getNftId(), riskId);

        // get risk data if risk exists
        if (exists) {
            cropRisk = abi.decode(
                reader.getRiskInfo(riskId).data, 
                (CropRisk));
        }
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
        (netPremiumAmount, ) = abi.decode(applicationData, (Amount, Amount[5]));
    }


    function getOracleNftId() public view returns (NftId oracleNftId) { return _oracleNftId; }

    function getRequestForRisk(RiskId riskId) public view returns (RequestId requestId) { return _requests[riskId]; }

    //--- internal functions ------------------------------------------------//


    // TODO cleanup
    // function createPolicy(
    //     address policyHolder,
    //     Str flightData, 
    //     Timestamp departureTime,
    //     string memory departureTimeLocal,
    //     Timestamp arrivalTime,
    //     string memory arrivalTimeLocal,
    //     Amount premiumAmount,
    //     uint256[6] memory statistics
    // )
    //     internal
    //     virtual
    //     returns (
    //         RiskId riskId,
    //         NftId policyNftId
    //     )
    // {

    //     (riskId, policyNftId) = _prepareApplication(
    //         policyHolder, 
    //         flightData,
    //         departureTime,
    //         departureTimeLocal,
    //         arrivalTime,
    //         arrivalTimeLocal,
    //         premiumAmount,
    //         statistics);

    //     _createPolicy(
    //         policyNftId, 
    //         TimestampLib.zero(), // do not ativate yet 
    //         premiumAmount); // max premium amount

    //     // interactions (token transfer + callback to token holder, if contract)
    //     _collectPremium(
    //         policyNftId, 
    //         departureTime); // activate at scheduled departure time of flight

    //     // send oracle request for for new risk 
    //     // if (_requests[riskId].eqz()) {
    //     //     _requests[riskId] = _sendRequest(
    //     //         _oracleNftId, 
    //     //         abi.encode(
    //     //             FlightOracle.FlightStatusRequest(
    //     //                 riskId,
    //     //                 flightData,
    //     //                 departureTime)),
    //     //         // allow up to 30 days to process the claim
    //     //         arrivalTime.addSeconds(SecondsLib.fromDays(30)), 
    //     //         "flightStatusCallback");
    //     // }
    // }


    // function _prepareApplication(
    //     address policyHolder,
    //     Str flightData, 
    //     Timestamp departureTime,
    //     string memory departureTimeLocal,
    //     Timestamp arrivalTime,
    //     string memory arrivalTimeLocal,
    //     Amount premiumAmount,
    //     uint256[6] memory statistics
    // )
    //     internal
    //     virtual
    //     returns (
    //         RiskId riskId,
    //         NftId policyNftId
    //     )
    // {
    //     Amount[5] memory payoutAmounts;
    //     Amount sumInsuredAmount;

    //     (
    //         riskId, 
    //         payoutAmounts,
    //         sumInsuredAmount
    //     ) = _createRiskAndPayoutAmounts(
    //         flightData,
    //         departureTime,
    //         departureTimeLocal,
    //         arrivalTime,
    //         arrivalTimeLocal,
    //         premiumAmount,
    //         statistics);

    //     policyNftId = _createApplication(
    //         policyHolder, 
    //         riskId, 
    //         sumInsuredAmount,
    //         premiumAmount,
    //         SecondsLib.toSeconds(180 * 24 * 3600), // 30 days
    //         _defaultBundleNftId, 
    //         ReferralLib.zero(), 
    //         abi.encode(
    //             premiumAmount,
    //             payoutAmounts)); // application data
    // }


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
        // (riskExists, statusAvailable, payoutOption) = FlightLib.getPayoutOption(reader, getNftId(), riskId);

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
            Amount payoutAmount = AmountLib.zero();

            // create claim/payout (if applicable)
            _resolvePayout(
                policyNftId, 
                payoutAmount); 

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