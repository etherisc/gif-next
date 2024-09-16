// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IClaimService} from "./IClaimService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, CLAIM, POLICY, POOL, PRODUCT} from "../type/ObjectType.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ProductStore} from "../instance/ProductStore.sol";
import {Service} from "../shared/Service.sol";
import {StateId} from "../type/StateId.sol";
import {SUBMITTED, KEEP_STATE, DECLINED, REVOKED, CANCELLED, CONFIRMED, CLOSED, EXPECTED, PAID} from "../type/StateId.sol";
import {TimestampLib} from "../type/Timestamp.sol";


contract ClaimService is 
    Service, 
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

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
        restricted()
        returns (ClaimId claimId)
    {
        // checks
        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check policy is in its active period
        if(policyInfo.activatedAt.eqz() || TimestampLib.current() >= policyInfo.expiredAt) {
            revert ErrorClaimServicePolicyNotOpen(policyNftId);
        }

        _checkClaimAmount(policyNftId, policyInfo, claimAmount);

        // effects
        // create new claim
        claimId = ClaimIdLib.toClaimId(policyInfo.claimsCount + 1);
        instanceContracts.instanceStore.createClaim(
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
        instanceContracts.productStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

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
        restricted()
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        // checks
        _checkNftType(policyNftId, POLICY());

        (
            NftId productNftId,
            IInstance instance,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        _checkClaimAmount(policyNftId, policyInfo, confirmedAmount);

        // effects
        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceContracts.instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.claimAmount = confirmedAmount;
        claimInfo.processData = data;
        instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());

        // update and save policy info with instance
        policyInfo.claimAmount = policyInfo.claimAmount + confirmedAmount;
        instanceContracts.productStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // should policy still be active it needs to become expired
        if (policyInfo.claimAmount >= policyInfo.sumInsuredAmount) {
            _policyService.expirePolicy(instance, policyNftId, TimestampLib.current());
        }

        emit LogClaimServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);

        // interactions
        // callback to pool if applicable
        _processConfirmedClaimByPool(instanceContracts.instanceReader, productNftId, policyNftId, claimId, confirmedAmount);

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
        restricted()
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        _checkNftType(policyNftId, POLICY());

        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceContracts.instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.processData = data;
        claimInfo.closedAt = TimestampLib.current();
        instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, DECLINED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instanceContracts.productStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimDeclined(policyNftId, claimId);
    }


    function revoke(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
        restricted()
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {        
        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceContracts.instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.closedAt = TimestampLib.current();
        instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, REVOKED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instanceContracts.productStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimRevoked(policyNftId, claimId);
    }


    function cancelConfirmedClaim(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
        restricted()
        // nonReentrant() // prevents creating a reinsurance claim in a single tx
    {
        _checkNftType(policyNftId, POLICY());
        
        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceContracts.instanceReader, policyNftId, claimId, CONFIRMED());

        // check claim has no open payouts
        if(claimInfo.openPayoutsCount > 0) {
            revert ErrorClaimServiceClaimWithOpenPayouts(
                policyNftId, 
                claimId, 
                claimInfo.openPayoutsCount);
        }

        claimInfo.closedAt = TimestampLib.current();
        instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, CANCELLED());

        emit LogClaimServiceClaimCancelled(policyNftId, claimId);
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
        restricted()
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
        restricted()
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
        restricted()
        // nonReentrant() // prevents creating a reinsurance payout in a single tx
        returns (Amount netPayoutAmount, Amount processingFeeAmount)
    {
        // checks
        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        IPolicy.ClaimInfo memory claimInfo;
        address payoutBeneficiary;
        Amount payoutAmount;
        
        {
            // check that payout exists and is open
            IPolicy.PayoutInfo memory payoutInfo = instanceContracts.instanceReader.getPayoutInfo(policyNftId, payoutId);
            payoutBeneficiary = payoutInfo.beneficiary;
            payoutAmount = payoutInfo.amount;
            StateId payoutState = instanceContracts.instanceReader.getPayoutState(policyNftId, payoutId);
            if(payoutState != EXPECTED()) {
                revert ErrorClaimServicePayoutNotExpected(policyNftId, payoutId, payoutState);
            }

            // check that payout amount does not violate claim amount
            claimInfo = instanceContracts.instanceReader.getClaimInfo(policyNftId, payoutId.toClaimId());
            if(claimInfo.paidAmount + payoutInfo.amount > claimInfo.claimAmount) {
                revert ErrorClaimServicePayoutExceedsClaimAmount(
                    policyNftId, 
                    payoutId.toClaimId(), 
                    claimInfo.claimAmount, 
                    claimInfo.paidAmount + payoutInfo.amount);
            }

            // effects
            // update and save payout info with instance
            payoutInfo.paidAt = TimestampLib.current();
            instanceContracts.instanceStore.updatePayout(policyNftId, payoutId, payoutInfo, PAID());
        }

        // update and save claim info with instance
        {
            ClaimId claimId = payoutId.toClaimId();
            claimInfo.paidAmount = claimInfo.paidAmount.add(payoutAmount);
            claimInfo.openPayoutsCount -= 1;

            // check if this payout is closing the linked claim
            // update claim and policy info accordingly
            if(claimInfo.openPayoutsCount == 0 && claimInfo.paidAmount == claimInfo.claimAmount) {
                claimInfo.closedAt = TimestampLib.current();
                instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, CLOSED());

                policyInfo.openClaimsCount -= 1;
            } else {
                instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
            }
        }

        // update and save policy info with instance
        policyInfo.payoutAmount = policyInfo.payoutAmount + payoutAmount;
        instanceContracts.productStore.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServicePayoutProcessed(policyNftId, payoutId, payoutAmount);

        // effects + interactions (push tokens to beneficiary, product)
        // delegate to pool to update book keeping and moving tokens payout
        (netPayoutAmount, processingFeeAmount) = _poolService.processPayout(
            instanceContracts.instanceReader,
            instanceContracts.instanceStore, 
            policyInfo.productNftId, // product nft id 
            policyNftId, 
            policyInfo.bundleNftId, 
            payoutId,
            payoutAmount,
            payoutBeneficiary);
    }

    function cancelPayout(
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
        restricted()
    {
        // checks
        (
            ,,
            IInstance.InstanceContracts memory instanceContracts,
        ) = _verifyCallerWithPolicy(policyNftId);

        StateId payoutState = instanceContracts.instanceReader.getPayoutState(policyNftId, payoutId);
        if (payoutState != EXPECTED()) {
            revert ErrorClaimServicePayoutNotExpected(policyNftId, payoutId, payoutState);
        }

        // effects
        // update and save payout info with instance
        instanceContracts.instanceStore.updatePayoutState(policyNftId, payoutId, CANCELLED());

        {
            ClaimId claimId = payoutId.toClaimId();
            IPolicy.ClaimInfo memory claimInfo = instanceContracts.instanceReader.getClaimInfo(policyNftId, claimId);
            claimInfo.openPayoutsCount -= 1;
            instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
        }

        emit LogClaimServicePayoutCancelled(policyNftId, payoutId);
    }

    // internal functions

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
            ,,
            IInstance.InstanceContracts memory instanceContracts,
            // IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        IPolicy.ClaimInfo memory claimInfo = instanceContracts.instanceReader.getClaimInfo(policyNftId, claimId);

        {
            // check claim state
            StateId claimState = instanceContracts.instanceReader.getClaimState(policyNftId, claimId);
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

        instanceContracts.instanceStore.createPayout(
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
        instanceContracts.instanceStore.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());

        emit LogClaimServicePayoutCreated(policyNftId, payoutId, amount, beneficiary);
    }

    /// @dev Verifies the caller is a product and the policy is active. 
    /// Returns the product nft id, instance, instance contracts and policy info.
    /// in InstanceContracts only the contracts instanceReader, instanceStore and productStore are set.
    function _verifyCallerWithPolicy(
        NftId policyNftId
    )
        internal
        view
        virtual
        returns (
            NftId productNftId,
            IInstance instance,
            IInstance.InstanceContracts memory instanceContracts,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        (productNftId, instance) = _getAndVerifyActiveProduct();
        instanceContracts.instanceReader = InstanceReader(instance.getInstanceReader());
        instanceContracts.instanceStore = InstanceStore(instance.getInstanceStore());
        instanceContracts.productStore = ProductStore(instance.getProductStore());

        // check caller(product) policy match
        policyInfo = instanceContracts.instanceReader.getPolicyInfo(policyNftId);
        if(policyInfo.productNftId != productNftId) {
            revert ErrorClaimServicePolicyProductMismatch(policyNftId, 
            policyInfo.productNftId, 
            productNftId);
        }
    }


    function _getAndVerifyActiveProduct() 
        internal 
        view 
        returns (
            NftId productNftId,
            IInstance instance
        )
    {
        (
            IRegistry.ObjectInfo memory info,
            address instanceAddress
        ) = ContractLib.getAndVerifyComponent(
            getRegistry(),
            msg.sender, // caller
            PRODUCT(),
            true); // isActive 

        // get component nft id and instance
        productNftId = info.nftId;
        instance = IInstance(instanceAddress);
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

    // TODO: move to policy helper lib or something
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