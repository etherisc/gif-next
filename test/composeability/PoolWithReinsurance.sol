// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {Fee} from "../../contracts/type/Fee.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../contracts/instance/module/IComponents.sol";
import {InstanceReader} from "../../contracts/instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {PolicyHolder} from "../../contracts/shared/PolicyHolder.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {ReferralLib} from "../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../contracts/type/Seconds.sol";
import {SimplePool} from "../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {TimestampLib} from "../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../contracts/type/UFixed.sol";

contract PoolWithReinsurance is
    PolicyHolder,
    SimplePool
{

    event LogPoolWithReinsurancePolicyCreated(NftId policyNftId);

    error ErrorPoolWithReinsuranceAlreadyCreated(NftId policyNftId);
    error ErrorPoolWithReinsuranceNoPolicy();

    SimpleProduct public reinsuranceProduct;
    NftId public resinsurancePolicyNftId;

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        IAuthorization authorization,
        address initialOwner
    ) 
        SimplePool(
            registry,
            instanceNftId,
            token,
            authorization,
            initialOwner
        )
    { 
        resinsurancePolicyNftId = NftIdLib.zero();
    }


    function createReinsurance(
        SimpleProduct product, // product that provides reinsurance
        uint256 sumInsured // sum insured for reinsurance
    )
        public
        virtual
    {
        if (resinsurancePolicyNftId.gtz()) {
            revert ErrorPoolWithReinsuranceAlreadyCreated(resinsurancePolicyNftId);
        }

        // step 0. remember product
        reinsuranceProduct = product;

        // step 1. create risk
        RiskId riskId = RiskIdLib.toRiskId("default");
        reinsuranceProduct.createRisk(riskId, "");

        // step 1. create application
        InstanceReader instanceReader = reinsuranceProduct.getInstance().getInstanceReader();
        NftId poolNftId = instanceReader.getProductInfo(reinsuranceProduct.getNftId()).poolNftId;
        resinsurancePolicyNftId = reinsuranceProduct.createApplication(
            address(this), 
            riskId, 
            sumInsured, 
            SecondsLib.toSeconds(365 * 24 * 3600), // lifetime
            "", // application data
            instanceReader.getActiveBundleNftId(poolNftId, 0),
            ReferralLib.zero()); // referral id

        // step 2. create active policy
        reinsuranceProduct.createPolicy(
            resinsurancePolicyNftId,
            false, // no premium collection required
            TimestampLib.blockTimestamp()); // active immediately

        emit LogPoolWithReinsurancePolicyCreated(resinsurancePolicyNftId);
    }


    function processConfirmedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount amount
    )
        public
        virtual override
    {
        if (resinsurancePolicyNftId.eqz()) {
            revert ErrorPoolWithReinsuranceNoPolicy();
        }

        // calculate missing funds
        Amount reinsuranceClaimAmount = amount;

        // create reinsurane claim
        reinsuranceProduct.submitClaim(
            resinsurancePolicyNftId, 
            reinsuranceClaimAmount, 
            ""); //submission data
    }


    function getInitialPoolInfo()
        public 
        virtual override
        view 
        returns (IComponents.PoolInfo memory poolInfo)
    {
        return IComponents.PoolInfo({
            maxBalanceAmount: AmountLib.max(),
            bundleOwnerRole: PUBLIC_ROLE(), 
            isInterceptingBundleTransfers: isNftInterceptor(),
            isProcessingConfirmedClaims: true,
            isExternallyManaged: false,
            isVerifyingApplications: false,
            collateralizationLevel: UFixedLib.one(),
            retentionLevel: UFixedLib.toUFixed(2, -1) // 20% of collateral needs to be held locally
        });
    }

}