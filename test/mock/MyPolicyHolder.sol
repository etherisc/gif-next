// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {IPolicy} from "../../contracts/instance/module/IPolicy.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PolicyHolder} from "../../contracts/shared/PolicyHolder.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralLib} from "../../contracts/type/Referral.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";

contract MyPolicyHolder is PolicyHolder {

    event LogMyPolicyHolderPolicyActivated(NftId policyNftId, Timestamp activatedAt);
    event LogMyPolicyHolderPolicyExpired(NftId policyNftId, Timestamp expiredAt);
    event LogMyPolicyHolderClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount claimAmount);
    event LogMyPolicyHolderPayoutExecuted(NftId policyNftId, PayoutId payoutId, Amount amount, address beneficiary);

    mapping(NftId => Timestamp activatedAt) public activatedAt;
    mapping(NftId => Timestamp expiredAt) public expiredAt;
    mapping(NftId => mapping(ClaimId claimId => Amount claimAmount)) public claimAmount;
    mapping(NftId => mapping(PayoutId payoutId => address beneficiary)) public beneficiary;
    mapping(NftId => mapping(PayoutId payoutId => Amount payoutAmount)) public payoutAmount;

    SimpleProduct public product;
    bool public isReentrant = false;

    constructor() {
        _initialize();
    }

    function _initialize() internal initializer() {
        __PolicyHolder_init();
    }

    // callback when policy is activated
    function policyActivated(
        NftId policyNftId, 
        Timestamp activated
    )
        external
        override
    {
        activatedAt[policyNftId] = activated;
        emit LogMyPolicyHolderPolicyActivated(policyNftId, activated);

        if (isReentrant) {
            IPolicy.PolicyInfo memory policy = product.getInstance().getInstanceReader().getPolicyInfo(policyNftId);

            // does hot trigger reentrancy (policy activation comes from policy service)
            NftId applicationNftId = product.createApplication({
                applicationOwner: address(this),
                riskId: policy.riskId,
                sumInsured: policy.sumInsuredAmount.toInt(),
                lifetime: policy.lifetime,
                applicationData: "",
                bundleNftId: policy.bundleNftId,
                referralId: ReferralLib.zero()
            });

            // this triggers reentrancy (policy activation comes from policy service)
            product.createPolicy(
                applicationNftId, 
                false, 
                TimestampLib.current());
        }
    }

    // callback when policy is expired
    function policyExpired(
        NftId policyNftId, 
        Timestamp expired
    )
        external
        override
    {
        expiredAt[policyNftId] = expired;
        emit LogMyPolicyHolderPolicyExpired(policyNftId, expired);
    }

    // callback function to notify the confirmed claim
    function claimConfirmed(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount
    )
        external
        override
    {
        claimAmount[policyNftId][claimId] = amount;
        emit LogMyPolicyHolderClaimConfirmed(policyNftId, claimId, amount);

        if (isReentrant) {
            IPolicy.PolicyInfo memory policy = product.getInstance().getInstanceReader().getPolicyInfo(policyNftId);
            product.submitClaim(policyNftId, amount, "");
        }
    }

    // callback function to notify the successful payout
    function payoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId, 
        Amount amount,
        address payoutRecipient // beneficiary
    )
        external
        override
    {
        payoutAmount[policyNftId][payoutId] = amount;
        beneficiary[policyNftId][payoutId] = payoutRecipient;
        emit LogMyPolicyHolderPayoutExecuted(policyNftId, payoutId, amount, payoutRecipient);
    }

    function setReentrant(SimpleProduct prd, bool reentrant) external {
        product = prd;
        isReentrant = reentrant;
    }
}