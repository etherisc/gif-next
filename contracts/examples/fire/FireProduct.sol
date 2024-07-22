// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ACTIVE, PAUSED} from "../../type/StateId.sol";
import {Amount, AmountLib} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
import {ClaimId} from "../../type/ClaimId.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IOracleService} from "../../oracle/IOracleService.sol";
import {ORACLE} from "../../type/ObjectType.sol";
import {NftId} from "../../type/NftId.sol";
import {PayoutId} from "../../type/PayoutId.sol";
import {ReferralId} from "../../type/Referral.sol";
import {RequestId} from "../../type/RequestId.sol";
import {RiskId} from "../../type/RiskId.sol";
import {Seconds} from "../../type/Seconds.sol";
import {StateId} from "../../type/StateId.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract FireProduct is 
    BasicProduct
{
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

    // TODO: do during application - probably no longer needed
    // function initializeCity(
    //     string memory cityName
    // ) 
    //     public 
    //     restricted()
    //     returns (RiskId riskId) 
    // {
    //     if (_riskMapping[cityName] != 0) {
    //         return _riskMapping[cityName];
    //     }
    //     riskId = _createRisk(
    //         id,
    //         data
    //     );
    //     _riskMapping[cityName] = riskId;
    // }

    function pauseCity(
        string memory cityName
    ) 
        public 
        restricted()
    {
        if (_riskMapping[cityName].eqz()) {
            revert(); // TODO: custom error
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
            revert(); // TODO: custom error
        }

        _updateRiskState(
            _riskMapping[cityName],
            ACTIVE()
        );
    }

    function createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsured,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        public
        returns (NftId nftId)
    {
        // TODO: create risk if not exists
        // TODO: imlement createApplication

        // Amount sumInsuredAmount = AmountLib.toAmount(sumInsured);
        // Amount premiumAmount = calculatePremium(
        //     sumInsuredAmount,
        //     riskId,
        //     lifetime,
        //     applicationData,
        //     bundleNftId,
        //     referralId);

        // return _createApplication(
        //     applicationOwner,
        //     riskId,
        //     sumInsuredAmount,
        //     premiumAmount,
        //     lifetime,
        //     bundleNftId,
        //     referralId,
        //     applicationData
        // );
    }

    function createPolicy(
        NftId applicationNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) public {
        // TODO: implement createPolicy

        // _createPolicy(applicationNftId, activateAt);
        // if (requirePremiumPayment == true) {
        //     _collectPremium(applicationNftId, activateAt);
        // }
    }

    function decline(
        NftId policyNftId
    ) public {
        // TODO: implement decline
        // _decline(policyNftId);
    }

    function expire(
        NftId policyNftId,
        Timestamp expireAt
    ) 
        public 
        returns (Timestamp)
    {
        // TODO: implement expire
        // return _expire(policyNftId, expireAt);
    }

    function close(
        NftId policyNftId
    ) public {
        // TODO: implement close
        // _close(policyNftId);
    }

    function submitClaim(
        NftId policyNftId,
        Amount claimAmount,
        bytes memory submissionData
    ) public returns (ClaimId) {
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