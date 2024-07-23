// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ACTIVE, PAUSED} from "../../type/StateId.sol";
import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {NftId} from "../../type/NftId.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {Timestamp} from "../../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../type/UFixed.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

function HALF_YEAR() pure returns (Seconds) {
    return Seconds.wrap(180 * 86400);
}

function ONE_YEAR() pure returns (Seconds) {
    return Seconds.wrap(360 * 86400);
}

/// @dev This is the product component for the fire insurance example. 
/// It show how to insure a house for a given suminsured in a city. 
/// The risk is based on the city. 
/// If a fire is reported in the city, the policy holder is able to submit a claim and get a payout. 
contract FireProduct is 
    BasicProduct
{
    error ErrorFireProductCityUnknown(string cityName);

    string[] private _cities;
    // map from city name to the RiskId
    mapping(string cityName => RiskId risk) private _riskMapping;

    constructor(
        address registry,
        NftId instanceNftid,
        string memory componentName,
        address token,
        address pool,
        IAuthorization authorization
    )
    {
        address initialOwner = msg.sender;
        _initialize(
            registry,
            instanceNftid,
            componentName,
            token,
            pool,
            authorization,
            initialOwner);
        initializeCity("London");
    }

    function _initialize(
        address registry,
        NftId instanceNftid,
        string memory componentName,
        address token,
        address pool,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicProduct(
            registry,
            instanceNftid,
            authorization,
            initialOwner,
            componentName,
            token,
            false,
            pool,
            address(0));  // no distribution
    }
    
    function cities() public view returns (uint256) {
        return _cities.length;
    }

    function city(uint256 idx) public view returns (string memory) {
        return _cities[idx];
    }

    function riskId(string memory cityName) public view returns (RiskId) {
        return _riskMapping[cityName];
    }

    function pauseCity(
        string memory cityName
    ) 
        public 
        restricted()
    {
        if (_riskMapping[cityName].eqz()) {
            revert ErrorFireProductCityUnknown(cityName);
        }

        _updateRiskState(
            _riskMapping[cityName],
            PAUSED()
        );
    }

    function unpauseCity(
        string memory cityName
    ) 
        public 
        restricted()
    {
        if (_riskMapping[cityName].eqz()) {
            revert ErrorFireProductCityUnknown(cityName);
        }

        _updateRiskState(
            _riskMapping[cityName],
            ACTIVE()
        );
    }

    function calculatePremium(
        string memory cityName,
        Amount sumInsured,
        Seconds lifetime,
        NftId bundleNftId
    ) 
        public
        view
        returns (Amount premiumAmount)
    {
        RiskId riskId = _riskMapping[cityName];
        if (riskId.eqz()) {
            revert ErrorFireProductCityUnknown(cityName);
        }
        premiumAmount = calculatePremium( 
            sumInsured,
            riskId,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());
    }

    function calculateNetPremium(
        Amount sumInsured,
        RiskId,
        Seconds lifetime,
        bytes memory
    )
        external
        view
        virtual override
        returns (Amount netPremiumAmount)
    {
        UFixed numDays = UFixedLib.toUFixed(lifetime.toInt() / 86400);
        // to simplify time calculation we assume 360 days per year
        UFixed pctOfYear = numDays / UFixedLib.toUFixed(360);
        Amount premiumPerYear = AmountLib.toAmount(sumInsured.toInt() / 20);
        return  premiumPerYear.multiplyWith(pctOfYear);
    }

    function createApplication(
        string memory cityName,
        Amount sumInsured,
        Seconds lifetime,
        NftId bundleNftId
    )
        public
        restricted()
        returns (NftId policyNftId)
    {
        address applicationOwner = msg.sender;
        RiskId riskId = initializeCity(cityName);

        Amount premiumAmount = calculatePremium(
            sumInsured,
            riskId,
            lifetime,
            "",
            bundleNftId,
            ReferralLib.zero());

        return _createApplication(
            applicationOwner,
            riskId,
            sumInsured,
            premiumAmount,
            lifetime,
            bundleNftId,
            ReferralLib.zero(),
            ""
        );
    }

    function initializeCity(
        string memory cityName
    ) 
        public
        returns (RiskId riskId) 
    {
        if (! _riskMapping[cityName].eqz()) {
            return _riskMapping[cityName];
        }
        _cities.push(cityName);
        riskId = RiskIdLib.toRiskId(cityName);
        _createRisk(riskId, "");
        _riskMapping[cityName] = riskId;
    }

    /// @dev Calling this method will lock the sum insured amount in the pool and activate the policy at the given time. 
    /// It will also collect the tokens payment for the premium. An approval with the correct amount towards the TokenHandler of the product is therefor required. 
    function createPolicy(
        NftId policyNftId,
        Timestamp activateAt
    ) 
        public 
        restricted()
    {
        _createPolicy(policyNftId, activateAt);
        _collectPremium(policyNftId, activateAt);
    }

    /// @dev Decline the policy application
    function decline(
        NftId policyNftId
    ) 
        public 
        restricted()
    {
        _decline(policyNftId);
    }

    function expire(
        NftId policyNftId,
        Timestamp expireAt
    ) 
        public 
        restricted()
        returns (Timestamp)
    {
        return _expire(policyNftId, expireAt);
    }

    function close(
        NftId policyNftId
    ) 
        public 
        restricted()
    {
        _close(policyNftId);
    }

    function submitClaim(
        NftId policyNftId,
        Amount claimAmount,
        bytes memory submissionData
    ) 
        public 
        restricted()
        returns (ClaimId) 
    {
        // TODO: implement submitClaim
        // return _submitClaim(policyNftId, claimAmount, submissionData);

        // TODO: check if fire was reported in the city
        // TODO: if yes, process payout and close claimn
        // TODO: if no, decline claim

    }

    // TODO: no longer needed? -> remove
    // function confirmClaim(
    //     NftId policyNftId,
    //     ClaimId claimId,
    //     Amount confirmedAmount,
    //     bytes memory processData
    // ) public {
    //     // TODO: implement confirmClaim
    //     // _confirmClaim(policyNftId, claimId, confirmedAmount, processData);
    // }

    // TODO: no longer needed? -> remove
    // function declineClaim(
    //     NftId policyNftId,
    //     ClaimId claimId,
    //     bytes memory processData
    // ) public {
    //     // TODO: implement declineClaim
    //     // _declineClaim(policyNftId, claimId, processData);
    // }

    // TODO: no longer needed? -> remove
    // function createPayout(
    //     NftId policyNftId,
    //     ClaimId claimId,
    //     Amount amount,
    //     bytes memory data
    // ) public returns (PayoutId) {
    //     return _createPayout(policyNftId, claimId, amount, data);
    // }

    // TODO: add method to report fire per city with a percentage of payout

    
    // TODO: no longer needed? -> remove
    // function processPayout(
    //     NftId policyNftId,
    //     PayoutId payoutId
    // ) public {
        // TODO: implement process all pending payouts for a risk - arguments cityname and payout percentage
    //     _processPayout(policyNftId, payoutId);
    // }


}