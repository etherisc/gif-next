// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ACTIVE, COLLATERALIZED, PAUSED} from "../../type/StateId.sol";
import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {DamageLevel, DamageLevelLib, DAMAGE_SMALL, DAMAGE_MEDIUM, DAMAGE_LARGE} from "./DamageLevel.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IPolicy} from "../../instance/module/IPolicy.sol";
import {NftId} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {ReferralLib} from "../../type/Referral.sol";
import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {StateId} from "../../type/StateId.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";
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
    struct Fire {
        string cityName;
        DamageLevel damageLevel;
        Timestamp reportedAt;
    }

    error ErrorFireProductCityUnknown(string cityName);
    error ErrorFireProductTimestampTooEarly();
    error ErrorFireProductFireAlreadyReported();
    error ErrorFireProductAlreadyClaimed();
    error ErrorFireProductPolicyNotActive();
    error ErrorFireProductPolicyNotYetActive(Timestamp activateAt);
    error ErrorFireProductPolicyExpired(Timestamp expiredAt);
    error ErrorFireProductUnknownDamageLevel(DamageLevel damageLevel);
    error ErrorFireProductFireUnknown(uint256 fireId);
    error ErrorFireProductNotPolicyOwner(NftId nftId, address owner);

    string[] private _cities;
    // map from city name to the RiskId
    mapping(string cityName => RiskId risk) private _riskMapping;

    // map from city name to the damage level and the time of the report
    mapping(uint256 fireId => Fire) private _fires;
    mapping(uint256 fireId => mapping (NftId policyId => bool claimed)) private _claimed;

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

    function reportFire(
        uint256 fireId,
        string memory cityName,
        DamageLevel damageLevel,
        Timestamp reportedAt
    ) 
        public 
        restricted()
    {
        if (_riskMapping[cityName].eqz()) {
            revert ErrorFireProductCityUnknown(cityName);
        }

        if (reportedAt < TimestampLib.blockTimestamp()) {
            revert ErrorFireProductTimestampTooEarly();
        }

        if (! _fires[fireId].reportedAt.eqz()) {
            revert ErrorFireProductFireAlreadyReported();
        }

        _fires[fireId] = Fire({
            cityName: cityName,
            damageLevel: damageLevel,
            reportedAt: reportedAt
        });
    }

    function fire(uint256 fireId) public view returns (Fire memory) {
        return _fires[fireId];
    }

    function submitClaim(
        NftId policyNftId,
        uint256 fireId
    ) 
        public 
        restricted()
        onlyNftOwner(policyNftId)
        returns (ClaimId claimId, PayoutId payoutId) 
    {
        IPolicy.PolicyInfo memory policyInfo = _getInstanceReader().getPolicyInfo(policyNftId);
        _checkClaimConditions(policyNftId, fireId, policyInfo);
        
        Fire memory fire = _fires[fireId];
        _claimed[fireId][policyNftId] = true;

        Amount claimAmount = _getClaimAmount(policyInfo, fire);
        Amount maxPayoutRemaining = policyInfo.sumInsuredAmount - policyInfo.payoutAmount;

        // if payout is higher than the remaining maximum payout, then claim what is remaining
        // TODO: leave claim amount as is and only confirm/payout reduced amount
        if (maxPayoutRemaining < claimAmount) {
            claimAmount = maxPayoutRemaining;
        }
        
        // TODO: encode some data claim

        claimId = _submitClaim(policyNftId, claimAmount, "");
        _confirmClaim(policyNftId, claimId, claimAmount, "");

        payoutId = _createPayout(policyNftId, claimId, claimAmount, "");
        _processPayout(policyNftId, payoutId);

        policyInfo = _getInstanceReader().getPolicyInfo(policyNftId);

        // TODO: switch to InstanceReader.policyIsCloseable 
        if (policyInfo.payoutAmount >= policyInfo.sumInsuredAmount) {
            close(policyNftId);
        }
    }

    function _checkClaimConditions(
        NftId policyNftId,
        uint256 fireId,
        IPolicy.PolicyInfo memory policyInfo
    ) 
        internal
    {
        // check fire exists
        if (_fires[fireId].reportedAt.eqz()) {
            revert ErrorFireProductFireUnknown(fireId);
        }

        // check policy has not been claimed yet for this fire
        if (_claimed[fireId][policyNftId]) {
            revert ErrorFireProductAlreadyClaimed();
        }

        StateId policyState = _getInstanceReader().getPolicyState(policyNftId);
        
        if (! policyState.eq(COLLATERALIZED())) {
            revert ErrorFireProductPolicyNotActive();
        }

        Fire memory fire = _fires[fireId];

        if (fire.reportedAt < policyInfo.activatedAt) {
            revert ErrorFireProductPolicyNotYetActive(policyInfo.activatedAt);
        }

        if (fire.reportedAt > policyInfo.expiredAt) {
            revert ErrorFireProductPolicyExpired(policyInfo.expiredAt);
        }
    }

    function _getClaimAmount(
        IPolicy.PolicyInfo memory policyInfo,
        Fire memory fire
    ) 
        internal
        view
        returns (Amount)
    {
        if (fire.damageLevel.eq(DAMAGE_SMALL())) {
            return policyInfo.sumInsuredAmount.multiplyWith(UFixedLib.toUFixed(25, -2));
        } else if (fire.damageLevel.eq(DAMAGE_MEDIUM())) {
            return policyInfo.sumInsuredAmount.multiplyWith(UFixedLib.toUFixed(5, -1));
        } else if (fire.damageLevel.eq(DAMAGE_LARGE())) {
            return policyInfo.sumInsuredAmount;
        } else {
            revert ErrorFireProductUnknownDamageLevel(fire.damageLevel);
        }
    }

}