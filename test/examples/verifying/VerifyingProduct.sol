// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
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

contract VerifyingProduct is 
    SimpleProduct
{

    RiskId public riskId;
    Amount public sumInsuredAmount;
    Amount public premiumAmount;
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
            new BasicProductAuthorization("VerifyingProduct"),
            initialOwner
        )
    {
    }

    function init() public {
        riskId = _createRisk("Risk1", "Risk1");

        sumInsuredAmount = AmountLib.toAmount(1000);
        premiumAmount = AmountLib.toAmount(100);
        policyDuration = SecondsLib.toSeconds(14 * 24 * 3600);
        referralId = ReferralLib.zero();
    }

    function createPolicy(
        uint256 applicationUint,
        NftId bundleNftId
    )
        external
        returns (NftId policyNftId)
    {
        address applicationOwner = msg.sender;
        policyNftId = _createApplication(
            applicationOwner,
            riskId,
            sumInsuredAmount,
            premiumAmount,
            policyDuration,
            bundleNftId,
            referralId,
            abi.encode(applicationUint));
        
        _createPolicy(
            policyNftId,
            TimestampLib.blockTimestamp());
    }
}