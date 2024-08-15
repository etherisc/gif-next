// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {ObjectType, CLAIM, POLICY, POOL, PRODUCT} from "../type/ObjectType.sol";
import {SUBMITTED, KEEP_STATE, DECLINED, REVOKED, CANCELLED, CONFIRMED, CLOSED, EXPECTED, PAID} from "../type/StateId.sol";
import {NftId} from "../type/NftId.sol";
import {FeeLib} from "../type/Fee.sol";
import {StateId} from "../type/StateId.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
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

    function _checkClaimAmount(
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        Amount claimAmount
    )
        internal
        pure
    {
        // check claim amount > 0
        if (claimAmount.eqz()) {
            revert ErrorClaimServiceClaimAmountIsZero(policyNftId);
        }

        // check policy including this claim is still within sum insured
        if(policyInfo.claimAmount + claimAmount > policyInfo.sumInsuredAmount) {
            revert ErrorClaimServiceClaimExceedsSumInsured(
                policyNftId, 
                policyInfo.sumInsuredAmount,
                policyInfo.payoutAmount + claimAmount);
        }
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
        // checks
        (
            ,
            IInstance instance,,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check policy is in its active period
        if(policyInfo.activatedAt.eqz() || TimestampLib.blockTimestamp() >= policyInfo.expiredAt) {
            revert ErrorClaimServicePolicyNotOpen(policyNftId);
        }

        _checkClaimAmount(policyNftId, policyInfo, claimAmount);

        // effects
        // create new claim
        claimId = ClaimIdLib.toClaimId(policyInfo.claimsCount + 1);
        instanceStore.createClaim(
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
        // policy claim amount is only updated when claim is confirmed
        policyInfo.claimsCount += 1;
        policyInfo.openClaimsCount += 1;
        instanceStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

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
        // checks
        _checkNftType(policyNftId, POLICY());

        (
            NftId productNftId,
            IInstance instance,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        _checkClaimAmount(policyNftId, policyInfo, confirmedAmount);

        // effects
        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.claimAmount = confirmedAmount;
        claimInfo.processData = data;
        instanceStore.updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());

        // update and save policy info with instance
        policyInfo.claimAmount = policyInfo.claimAmount + confirmedAmount;
        instanceStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // should policy still be active it needs to become expired
        if (policyInfo.claimAmount >= policyInfo.sumInsuredAmount) {
            _policyService.expirePolicy(instance, policyNftId, TimestampLib.blockTimestamp());
        }

        emit LogClaimServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);

        // interactions
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
        _checkNftType(policyNftId, POLICY());

        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.processData = data;
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instanceStore.updateClaim(policyNftId, claimId, claimInfo, DECLINED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instanceStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimDeclined(policyNftId, claimId);
    }


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
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instanceStore.updateClaim(policyNftId, claimId, claimInfo, REVOKED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instanceStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

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
        _checkNftType(policyNftId, POLICY());
        
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
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
        instanceStore.updateClaim(policyNftId, claimId, claimInfo, CLOSED());
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
        _checkNftType(policyNftId, POLICY());
        
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
        // checks
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check that payout exists and is open
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);
        StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
        if(payoutState != EXPECTED()) {
            revert ErrorClaimServicePayoutNotExpected(policyNftId, payoutId, payoutState);
        }

        // check that payout amount does not violate claim amount
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, payoutId.toClaimId());
        if(claimInfo.paidAmount + payoutInfo.amount > claimInfo.claimAmount) {
            revert ErrorClaimServicePayoutExceedsClaimAmount(
                policyNftId, 
                payoutId.toClaimId(), 
                claimInfo.claimAmount, 
                claimInfo.paidAmount + payoutInfo.amount);
        }

        // effects
        // update and save payout info with instance
        payoutInfo.paidAt = TimestampLib.blockTimestamp();
        instanceStore.updatePayout(policyNftId, payoutId, payoutInfo, PAID());

        Amount payoutAmount = payoutInfo.amount;

        {
            ClaimId claimId = payoutId.toClaimId();
            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            claimInfo.paidAmount = claimInfo.paidAmount.add(payoutAmount);
            claimInfo.openPayoutsCount -= 1;

            // check if this payout is closing the linked claim
            // update claim and policy info accordingly
            if(claimInfo.openPayoutsCount == 0 && claimInfo.paidAmount == claimInfo.claimAmount) {
                claimInfo.closedAt = TimestampLib.blockTimestamp();
                instanceStore.updateClaim(policyNftId, claimId, claimInfo, CLOSED());

                policyInfo.openClaimsCount -= 1;
            } else {
                instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
            }
        }

        // update and save policy info with instance
        policyInfo.payoutAmount = policyInfo.payoutAmount + payoutAmount;
        instanceStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // inform pool about payout
        _poolService.processPayout(
            instance, 
            address(instanceReader.getComponentInfo(policyInfo.productNftId).token),
            policyNftId, 
            policyInfo, 
            payoutAmount);
        
        // transfer payout token and fee
        {
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
                poolInfo.tokenHandler.pushToken(
                    beneficiary, 
                    netPayoutAmount);

                // TODO add 2nd token tx if processingFeeAmount > 0
            }

            // callback to policy holder if applicable
            _policyHolderPayoutExecuted(policyNftId, payoutId, beneficiary, payoutAmount);
        }
    }

    function cancelPayout(
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
    {
        // checks
        (
            ,
            IInstance instance,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        StateId payoutState = instanceReader.getPayoutState(policyNftId, payoutId);
        if (payoutState != EXPECTED()) {
            revert ErrorClaimServicePayoutNotExpected(policyNftId, payoutId, payoutState);
        }

        // effects
        // update and save payout info with instance
        instanceStore.updatePayoutState(policyNftId, payoutId, CANCELLED());

        {
            ClaimId claimId = payoutId.toClaimId();
            IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
            claimInfo.openPayoutsCount -= 1;
            instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
        }

        emit LogClaimServicePayoutCancelled(policyNftId, payoutId);
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
        // checks
        (
            ,
            ,
            InstanceReader instanceReader,
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);

        {
            // check claim state
            StateId claimState = instanceReader.getClaimState(policyNftId, claimId);
            if (claimState != CONFIRMED()) {
                revert ErrorClaimServiceClaimNotConfirmed(policyNftId, claimId, claimState);
            }

            // check total payout amount remains within claim limit
            Amount newPaidAmount = claimInfo.paidAmount + amount;
            if (newPaidAmount > claimInfo.claimAmount) {
                revert ErrorClaimServicePayoutExceedsClaimAmount(
                    policyNftId, claimId, claimInfo.claimAmount, newPaidAmount);
            }
        }

        // effects
        // create payout info with instance
        uint24 payoutNo = claimInfo.payoutsCount + 1;
        payoutId = PayoutIdLib.toPayoutId(claimId, payoutNo);
        if (beneficiary == address(0)) {
            beneficiary = getRegistry().ownerOf(policyNftId);
        }

        instanceStore.createPayout(
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
        instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());

        emit LogClaimServicePayoutCreated(policyNftId, payoutId, amount, beneficiary);
    }


    function _calculatePayoutAmount(
        InstanceReader instanceReader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        IPolicy.PayoutInfo memory payoutInfo
    )
        internal
        view
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
            InstanceStore instanceStore,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        (productNftId,, instance) = _getAndVerifyActiveComponent(PRODUCT());
        instanceReader = instance.getInstanceReader();
        instanceStore = instance.getInstanceStore();

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