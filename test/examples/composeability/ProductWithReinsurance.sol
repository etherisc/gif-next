// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {FeeLib} from "../../../contracts/type/Fee.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {NftId} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {ReferralId} from "../../../contracts/type/Referral.sol";
import {RequestId} from "../../../contracts/type/RequestId.sol";
import {RiskId} from "../../../contracts/type/RiskId.sol";
import {Seconds} from "../../../contracts/type/Seconds.sol";
import {StateId} from "../../../contracts/type/StateId.sol";
import {Timestamp, TimestampLib} from "../../../contracts/type/Timestamp.sol";

contract ProductWithReinsurance is 
    SimpleProduct
{

    mapping(NftId policyNftId => mapping(ClaimId claimId => Amount funding)) public claimFundingAmount;
    bool public isAutoPayout;

    constructor(
        address registry,
        NftId instanceNftid,
        IAuthorization authorization,
        address initialOwner,
        address token
    )
        SimpleProduct(
            registry,
            instanceNftid,
            authorization,
            initialOwner,
            token,
            false, // isInterceptor
            false, // has distribution
            0 // number of oracles
        )
    {
        isAutoPayout = false;
    }

    event LogProductWithReinsuranceFundedClaim(NftId policyNftId, ClaimId claimId, Amount availableAmount);

    function setAutoPayout(bool autoPayout) external {
        isAutoPayout = autoPayout;
    }

    // could trigger process payout but only records funding
    // to check in testing
    function processFundedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount availableAmount
    )
        external
        virtual override
        restricted() // pool service role
    {
        claimFundingAmount[policyNftId][claimId] = availableAmount;

        emit LogProductWithReinsuranceFundedClaim(policyNftId, claimId, availableAmount);

        if (isAutoPayout) {
            PayoutId payoutId = createPayout(
                policyNftId, 
                claimId, 
                _getInstanceReader().getClaimInfo(
                    policyNftId, 
                    claimId).claimAmount, // payout amount is the claim amount 
                "");

            processPayout(policyNftId, payoutId);
        }
    }


    function getInitialProductInfo()
        public 
        virtual override
        view 
        returns (IComponents.ProductInfo memory productInfo)
    {
        productInfo = super.getInitialProductInfo();
        productInfo.isProcessingFundedClaims = true;
        productInfo.hasDistribution = false;
        productInfo.numberOfOracles = 0;
    }
}