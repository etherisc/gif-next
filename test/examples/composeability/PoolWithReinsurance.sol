// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {Fee} from "../../../contracts/type/Fee.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {InstanceReader} from "../../../contracts/instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {PolicyHolder} from "../../../contracts/shared/PolicyHolder.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract PoolWithReinsurance is
    PolicyHolder,
    SimplePool
{

    event LogPoolWithReinsurancePolicyCreated(NftId policyNftId);

    error ErrorPoolWithReinsuranceAlreadyCreated(NftId policyNftId);
    error ErrorPoolWithReinsuranceNoPolicy();

    SimpleProduct public reinsuranceProduct;
    NftId public resinsurancePolicyNftId;
    UFixed public retentionLevel;
    UFixed public reinsuranceLevel;

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
            IComponents.PoolInfo({
                maxBalanceAmount: AmountLib.max(),
                isInterceptingBundleTransfers: false,
                isProcessingConfirmedClaims: false,
                isExternallyManaged: false,
                isVerifyingApplications: false,
                collateralizationLevel: UFixedLib.one(),
                retentionLevel: UFixedLib.toUFixed(2, -1)
            }),
            initialOwner
        )
    { 
        retentionLevel = UFixedLib.toUFixed(2, -1); // 20% of collateral needs to be held locally
        reinsuranceLevel = UFixedLib.toUFixed(8, -1); // 80% of claims are reinsured
        resinsurancePolicyNftId = NftIdLib.zero();

        _initialize(registry);
    }

    function _initialize(address registry)
        internal 
        initializer()
    {
        _initializePolicyHolder(registry);
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
        // THIS IS NOT REALISTICALLY done here (but is the simples possible setup to 
        // test composition)
        // in a real setup the policy would be created by the reinsurance product
        reinsuranceProduct.createPolicy(
            resinsurancePolicyNftId,
            false, // no premium collection required
            TimestampLib.blockTimestamp()); // active immediately

        emit LogPoolWithReinsurancePolicyCreated(resinsurancePolicyNftId);
    }

    // clallback once product has confirmed a claim
    function processConfirmedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount amount
    )
        public
        virtual override
        restricted()
    {
        if (resinsurancePolicyNftId.eqz()) {
            revert ErrorPoolWithReinsuranceNoPolicy();
        }

        // calculate missing funds
        Amount reinsuranceClaimAmount = AmountLib.toAmount(
            (reinsuranceLevel * amount.toUFixed()).toInt());

        // create reinsurane claim
        ClaimId reinsuranceClaimId = reinsuranceProduct.submitClaim(
            resinsurancePolicyNftId, 
            reinsuranceClaimAmount, 
            encodeClaimData(
                policyNftId, 
                claimId)); // claim submission data

        // claim confirmation and payout handling done here to
        // simplify overall setup (reuse of simple product)    
        // THIS IS NOT REALISTICALLY done here (but is the
        // responsibility of the reinsurance product's claim processing)
        reinsuranceProduct.confirmClaim(
            resinsurancePolicyNftId, 
            reinsuranceClaimId, 
            reinsuranceClaimAmount, 
            ""); // claim processing data
        
        // IMPORTANT: ensure that payout goes to current pool wallet
        // it must not be possible to change the pool wallet inbetween
        // payout creation and processing
        PayoutId reinsurancePayoutId = reinsuranceProduct.createPayoutForBeneficiary(
            resinsurancePolicyNftId, 
            reinsuranceClaimId, 
            reinsuranceClaimAmount, 
            getWallet(), // pool wallet
            ""); // payout data
        
        reinsuranceProduct.processPayout(
            resinsurancePolicyNftId, 
            reinsurancePayoutId);
    }

    event LogPoolWithReinsurancePayoutExecuted();

    // callback from reinsurance payout to this pool as policy holder
    function payoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId, 
        Amount amount, 
        address beneficiary
    )
        external
        virtual override
        restricted()
    {
        ClaimId reinsuranceClaimId = payoutId.toClaimId();
        InstanceReader instanceReader = reinsuranceProduct.getInstance().getInstanceReader();
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(
            policyNftId, reinsuranceClaimId);

        (
            NftId claimingPolicyNftId, 
            ClaimId sourceClaimId
        ) = decodeClaimData(claimInfo.submissionData);

        emit LogPoolWithReinsurancePayoutExecuted();

        // trigger callback to product 
        _processFundedClaim(
            claimingPolicyNftId, 
            sourceClaimId, 
            amount);
    }


    function encodeClaimData(NftId claimingPolicyNftId, ClaimId sourceClaimId)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(claimingPolicyNftId, sourceClaimId);
    }


    function decodeClaimData(bytes memory claimData)
        public
        pure
        returns (
            NftId claimingPolicyNftId, 
            ClaimId sourceClaimId
        )
    {
        return abi.decode(claimData, (NftId, ClaimId));
    }

    // TODO cleanup
    // function getInitialPoolInfo()
    //     public 
    //     virtual override
    //     view 
    //     returns (IComponents.PoolInfo memory poolInfo)
    // {
    //     return IComponents.PoolInfo({
    //         maxBalanceAmount: AmountLib.max(),
    //         isInterceptingBundleTransfers: isNftInterceptor(),
    //         isProcessingConfirmedClaims: true,
    //         isExternallyManaged: false,
    //         isVerifyingApplications: false,
    //         collateralizationLevel: UFixedLib.one(),
    //         retentionLevel: retentionLevel
    //     });
    // }

}