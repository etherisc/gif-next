// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {ObjectType, CLAIM, POLICY, POOL, PRODUCT} from "../type/ObjectType.sol";
import {SUBMITTED, KEEP_STATE, DECLINED, REVOKED, CONFIRMED, CLOSED, PAID} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {FeeLib} from "../type/Fee.sol";
import {StateId} from "../type/StateId.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IClaimService} from "./IClaimService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";


contract ClaimService is 
    ComponentVerifyingService, 
    IClaimService
{

    IPolicyService internal _policyService;
    IPoolService internal _poolService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

        _policyService = IPolicyService(getRegistry().getServiceAddress(POLICY(), getVersion().toMajorPart()));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));

        _registerInterface(type(IClaimService).interfaceId);
    }

    function submit(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData // claim submission data
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
        returns (ClaimId claimId)
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check policy is in its active period
        if(policyInfo.activatedAt.eqz() || TimestampLib.blockTimestamp() >= policyInfo.expiredAt) {
            revert ErrorClaimServicePolicyNotOpen(policyNftId);
        }

        // TODO check claim amount > 0
        // check policy including this claim is still within sum insured
        if(policyInfo.payoutAmount + claimAmount > policyInfo.sumInsuredAmount) {
            revert ErrorClaimServiceClaimExceedsSumInsured(
                policyNftId, 
                policyInfo.sumInsuredAmount,
                AmountLib.toAmount(policyInfo.payoutAmount.toInt() + claimAmount.toInt()));
        }

        // create new claim
        claimId = ClaimIdLib.toClaimId(policyInfo.claimsCount + 1);
        instance.getInstanceStore().createClaim(
            policyNftId, 
            claimId, 
            IPolicy.ClaimInfo({
                claimAmount: claimAmount,
                paidAmount: AmountLib.zero(),
                payoutsCount: 0,
                openPayoutsCount: 0,
                submissionData: claimData,
                processData: "",
                closedAt: TimestampLib.zero()}));

        // update and save policy info with instance
        policyInfo.claimsCount += 1;
        policyInfo.openClaimsCount += 1;
        // policy claim amount is only updated when claim is confirmed
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimSubmitted(policyNftId, claimId, claimAmount);
    }


    function confirm(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount,
        bytes memory data // claim processing data
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        (
            NftId productNftId,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // TODO add check for confirmedAmount > 0 and does not lead to exceeding sum insured

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.claimAmount = confirmedAmount;
        claimInfo.processData = data;
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());

        // update and save policy info with instance
        policyInfo.claimAmount = policyInfo.claimAmount + confirmedAmount;
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // should policy still be active it needs to become expired
        if (policyInfo.claimAmount >= policyInfo.sumInsuredAmount) {
            _policyService.expirePolicy(instance, policyNftId, TimestampLib.blockTimestamp());
        }

        emit LogClaimServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);

        // callback to pool if applicable
        _processConfirmedClaimByPool(instanceReader, productNftId, policyNftId, claimId, confirmedAmount);

        // callback to policy holder if applicable
        _policyHolderClaimConfirmed(policyNftId, claimId, confirmedAmount);
    }


    function decline(
        NftId policyNftId, 
        ClaimId claimId,
        bytes memory data // claim processing data
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.processData = data;
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, DECLINED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimDeclined(policyNftId, claimId);
    }


    // TODO add test case
    function revoke(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, REVOKED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimRevoked(policyNftId, claimId);
    }


    function close(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, CONFIRMED());

        // check claim has no open payouts
        if(claimInfo.openPayoutsCount > 0) {
            revert ErrorClaimServiceClaimWithOpenPayouts(
                policyNftId, 
                claimId, 
                claimInfo.openPayoutsCount);
        }

        // check claim paid amount matches with claim amount
        if(claimInfo.paidAmount.toInt() < claimInfo.claimAmount.toInt()) {
            revert ErrorClaimServiceClaimWithMissingPayouts(
                policyNftId, 
                claimId, 
                claimInfo.claimAmount,
                claimInfo.paidAmount);
        }

        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, CLOSED());
    }


    function createPayoutForBeneficiary(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        address beneficiary,
        bytes memory data
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
        returns (PayoutId payoutId)
    {
        if (beneficiary == address(0)) {
            revert ErrorClaimServiceBeneficiaryIsZero(policyNftId, claimId);
        }

        return _createPayout(
            policyNftId, 
            claimId, 
            amount, 
            beneficiary,
            data);
    }


    function createPayout(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        bytes memory data
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance payout in a single tx
        returns (PayoutId payoutId)
    {
        return _createPayout(
            policyNftId, 
            claimId, 
            amount, 
            address(0), // defaults to owner of policy nft
            data);
    }


    function processPayout(
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
        // nonReentrant() // prevents creating a reinsurance payout in a single tx
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // TODO add check that payout exists and is open
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);

        // update and save payout info with instance
        payoutInfo.paidAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updatePayout(policyNftId, payoutId, payoutInfo, PAID());

        ClaimId claimId = payoutId.toClaimId();
        Amount payoutAmount = payoutInfo.amount;
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        claimInfo.paidAmount = claimInfo.paidAmount.add(payoutAmount);
        claimInfo.openPayoutsCount -= 1;

        // check if this payout is closing the linked claim
        // update claim and policy info accordingly
        if(claimInfo.openPayoutsCount == 0 && claimInfo.paidAmount == claimInfo.claimAmount) {
            claimInfo.closedAt = TimestampLib.blockTimestamp();
            instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, CLOSED());

            policyInfo.openClaimsCount -= 1;
        } else {
            instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
        }

        // update and save policy info with instance
        policyInfo.payoutAmount = policyInfo.payoutAmount.add(payoutAmount);
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // inform pool about payout
        _poolService.processPayout(
            instance, 
            address(instanceReader.getComponentInfo(policyInfo.productNftId).token),
            policyNftId, 
            policyInfo, 
            payoutAmount);
        
        // transfer payout token and fee
        (
            Amount netPayoutAmount,
            Amount processingFeeAmount,
            address beneficiary
        ) = _calculatePayoutAmount(
            instanceReader,
            policyNftId,
            policyInfo,
            payoutInfo);

        emit LogClaimServicePayoutProcessed(policyNftId, payoutId, payoutAmount, beneficiary, netPayoutAmount, processingFeeAmount);

        {
            NftId poolNftId = getRegistry().getObjectInfo(policyInfo.bundleNftId).parentNftId;
            IComponents.ComponentInfo memory poolInfo = instanceReader.getComponentInfo(poolNftId);
            poolInfo.tokenHandler.distributeTokens(poolInfo.wallet, beneficiary, netPayoutAmount);

            // TODO add 2nd token tx if processingFeeAmount > 0
        }

        // callback to policy holder if applicable
        _policyHolderPayoutExecuted(policyNftId, payoutId, beneficiary, payoutAmount);
    }

    // internal functions


    function _createPayout(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        address beneficiary,
        bytes memory data
    )
        internal
        virtual
        returns (PayoutId payoutId)
    {
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        StateId claimState = instanceReader.getClaimState(policyNftId, claimId);

        // TODO add checks
        // claim needs to be open
        // claim.paidAmount + amount <= claim.claimAmount

        // check/update claim info
        // create payout info with instance
        uint24 payoutNo = claimInfo.payoutsCount + 1;
        payoutId = PayoutIdLib.toPayoutId(claimId, payoutNo);
        if (beneficiary == address(0)) {
            beneficiary = getRegistry().ownerOf(policyNftId);
        }
        instance.getInstanceStore().createPayout(
            policyNftId, 
            payoutId, 
            IPolicy.PayoutInfo({
                claimId: payoutId.toClaimId(),
                amount: amount,
                beneficiary: beneficiary,
                data: data,
                paidAt: TimestampLib.zero()}));

        // update and save claim info with instance
        claimInfo.payoutsCount += 1;
        claimInfo.openPayoutsCount += 1;
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());

        // update and save policy info with instance
        policyInfo.payoutAmount.add(amount);
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServicePayoutCreated(policyNftId, payoutId, amount, beneficiary);
    }


    function _calculatePayoutAmount(
        InstanceReader instanceReader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        IPolicy.PayoutInfo memory payoutInfo
    )
        internal
        returns (
            Amount netPayoutAmount,
            Amount processingFeeAmount,
            address beneficiary
        )
    {
        Amount payoutAmount = payoutInfo.amount;

        if(payoutAmount.gtz()) {
            NftId productNftId = policyInfo.productNftId;

            // get pool component info from policy or product
            NftId poolNftId = getRegistry().getObjectInfo(policyInfo.bundleNftId).parentNftId;
            IComponents.ComponentInfo memory poolInfo = instanceReader.getComponentInfo(poolNftId);

            netPayoutAmount = payoutAmount;

            if (payoutInfo.beneficiary == address(0)) {
                beneficiary = getRegistry().ownerOf(policyNftId);
            } else { 
                beneficiary = payoutInfo.beneficiary;
            }

            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            if(FeeLib.gtz(productInfo.processingFee)) {
                // TODO calculate and set net payout and processing fees
            }
        }
    }


    function _verifyCallerWithPolicy(
        NftId policyNftId
    )
        internal
        view
        virtual
        returns (
            NftId productNftId,
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        (productNftId,, instance) = _getAndVerifyActiveComponent(PRODUCT());
        instanceReader = instance.getInstanceReader();

        // check caller(product) policy match
        policyInfo = instanceReader.getPolicyInfo(policyNftId);
        if(policyInfo.productNftId != productNftId) {
            revert ErrorClaimServicePolicyProductMismatch(policyNftId, 
            policyInfo.productNftId, 
            productNftId);
        }
    }

    function _verifyClaim(
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId, 
        StateId expectedState
    )
        internal
        view
        returns (
            IPolicy.ClaimInfo memory claimInfo
        )
    {
        // check claim is created state
        StateId claimState = instanceReader.getClaimState(policyNftId, claimId);
        if(claimState != expectedState) {
            revert ErrorClaimServiceClaimNotInExpectedState(
                policyNftId, claimId, expectedState, claimState);
        }

        // get claim info
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
    }

    function _processConfirmedClaimByPool(
        InstanceReader instanceReader, 
        NftId productNftId, 
        NftId policyNftId, 
        ClaimId claimId, 
        Amount amount
    )
        internal
    {
        NftId poolNftId = instanceReader.getProductInfo(productNftId).poolNftId;
        if (instanceReader.getPoolInfo(poolNftId).isProcessingConfirmedClaims) {
            address poolAddress = getRegistry().getObjectAddress(poolNftId);
            IPoolComponent(poolAddress).processConfirmedClaim(policyNftId, claimId, amount);
        }
    }


    function _policyHolderClaimConfirmed(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount
    )
        internal
    {
        IPolicyHolder policyHolder = _getPolicyHolder(policyNftId);
        if(address(policyHolder) != address(0)) {
            policyHolder.claimConfirmed(policyNftId, claimId, confirmedAmount);
        }
    }


    function _policyHolderPayoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId,
        address beneficiary,
        Amount payoutAmount
    )
        internal
    {
        IPolicyHolder policyHolder = _getPolicyHolder(policyNftId);
        if(address(policyHolder) != address(0)) {
            policyHolder.payoutExecuted(policyNftId, payoutId, payoutAmount, beneficiary);
        }
    }


    function _getPolicyHolder(NftId policyNftId)
        internal 
        view 
        returns (IPolicyHolder policyHolder)
    {
        address policyHolderAddress = getRegistry().ownerOf(policyNftId);
        policyHolder = IPolicyHolder(policyHolderAddress);

        if (!ContractLib.isPolicyHolder(policyHolderAddress)) {
            policyHolder = IPolicyHolder(address(0));
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return CLAIM();
    }
}