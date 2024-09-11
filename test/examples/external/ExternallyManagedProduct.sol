// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol"; 
// import {ExternallyManagedProductAuthorization} from "./ExternallyManagedProductAuthorization.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {StateId} from "../../../contracts/type/StateId.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

contract ExternallyManagedProduct is 
    SimpleProduct
{

    RiskId public riskId;
    Seconds public policyDuration;
    ReferralId public referralId;

    constructor(
        address registry,
        NftId instanceNftId,
        IComponents.ProductInfo memory productInfo,
        IComponents.FeeInfo memory feeInfo,
        address initialOwner
    )
        SimpleProduct(
            registry,
            instanceNftId,
            "VerifyingProduct", 
            productInfo,
            feeInfo,
            new BasicProductAuthorization("ExternallyManagedProduct"),
            initialOwner
        )
    {
    }

    function init() public {
        riskId = _createRisk("Risk1", "Risk1");

        policyDuration = SecondsLib.toSeconds(14 * 24 * 3600);
        referralId = ReferralLib.zero();
    }

    function createPolicy(
        Amount sumInsuredAmount,
        Amount estimatedPremiumAmount,
        NftId bundleNftId
    )
        external
        returns (
            NftId policyNftId,
            Amount premiumAmount
        )
    {
        address applicationOwner = msg.sender;
        policyNftId = _createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            estimatedPremiumAmount,
            policyDuration,
            bundleNftId,
            referralId,
            "");
        
        premiumAmount = _createPolicy(
            policyNftId,
            TimestampLib.current(),
            AmountLib.max());

        _collectPremium(
            policyNftId,
            TimestampLib.current());
    }


    function closePolicy(
        NftId policyNftId
    )
        external
    {
        _close(policyNftId);
    }


    function createAndProcessPayout(
        NftId policyNftId,
        Amount amount
    )
        external
        returns (
            ClaimId claimId,
            PayoutId payoutId
        )
    {
        claimId = _submitClaim(
            policyNftId,
            amount,
            "");

        _confirmClaim(
            policyNftId,
            claimId,
            amount,
            "");

        payoutId = _createPayout(
            policyNftId,
            claimId,
            amount,
            "");

        _processPayout(
            policyNftId,
            payoutId);
    }
}