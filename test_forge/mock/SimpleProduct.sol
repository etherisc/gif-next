// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {Fee} from "../../contracts/type/Fee.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {Product} from "../../contracts/components/Product.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {StateId} from "../../contracts/type/StateId.sol";
import {Timestamp, Seconds} from "../../contracts/type/Timestamp.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract SimpleProduct is Product {

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner
    )
    {
        initialize(
            registry,
            instanceNftid,
            "SimpleProduct",
            token,
            isInterceptor,
            pool,
            distribution,
            productFee,
            processingFee,
            initialOwner); 
    }


    function initialize(
        address registry,
        NftId instanceNftid,
        string memory name,
        address token,
        bool isInterceptor,
        address pool,
        address distribution,
        Fee memory productFee,
        Fee memory processingFee,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        initializeProduct(
            registry,
            instanceNftid,
            name,
            token,
            isInterceptor,
            pool,
            distribution,
            productFee,
            processingFee,
            initialOwner,
            ""); 
    }

    function createRisk(
        RiskId id,
        bytes memory data
    ) public {
        _createRisk(
            id,
            data
        );
    }

    function updateRisk(
        RiskId id,
        bytes memory data
    ) public {
        _updateRisk(
            id,
            data
        );
    }

    function updateRiskState(
        RiskId id,
        StateId state
    ) public {
        _updateRiskState(
            id,
            state
        );
    }
    
    function createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) public returns (NftId nftId) {
        return _createApplication(
            applicationOwner,
            riskId,
            AmountLib.toAmount(sumInsuredAmount),
            lifetime,
            bundleNftId,
            referralId,
            applicationData
        );
    }

    function collateralize(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    ) public {
        _collateralize(policyNftId, requirePremiumPayment, activateAt);
    }

    function collectPremium(
        NftId policyNftId,
        Timestamp activateAt
    ) public {
        _collectPremium(policyNftId, activateAt);
    }

    function activate(
        NftId policyNftId,
        Timestamp activateAt
    ) public {
        _activate(policyNftId, activateAt);
    }

    function close(
        NftId policyNftId
    ) public {
        _close(policyNftId);
    }

    function submitClaim(
        NftId policyNftId,
        Amount claimAmount,
        bytes memory claimData
    ) public returns (ClaimId) {
        return _submitClaim(policyNftId, claimAmount, claimData);
    }

    function confirmClaim(
        NftId policyNftId,
        ClaimId claimId,
        Amount confirmedAmount
    ) public {
        _confirmClaim(policyNftId, claimId, confirmedAmount);
    }

    function declineClaim(
        NftId policyNftId,
        ClaimId claimId
    ) public {
        _declineClaim(policyNftId, claimId);
    }

    function closeClaim(
        NftId policyNftId,
        ClaimId claimId
    ) public {
        _closeClaim(policyNftId, claimId);
    }

    function createPayout(
        NftId policyNftId,
        ClaimId claimId,
        Amount amount,
        bytes memory data
    ) public returns (PayoutId) {
        return _createPayout(policyNftId, claimId, amount, data);
    }

    function processPayout(
        NftId policyNftId,
        PayoutId payoutId
    ) public {
        _processPayout(policyNftId, payoutId);
    }

    function doSomethingSpecial() 
        public 
        restricted()
        returns (bool) 
    {
        return true;
    }

    function doWhenNotLocked() 
        public 
        restricted()
        returns (bool) 
    {
        return true;
    }

}