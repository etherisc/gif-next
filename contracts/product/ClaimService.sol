// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRisk} from "../instance/module/IRisk.sol";
import {IService} from "./IApplicationService.sol";

import {IComponents} from "../instance/module/IComponents.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IProductComponent} from "./IProductComponent.sol";
import {Product} from "./Product.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IProductService} from "./IProductService.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, CLAIM, BUNDLE} from "../type/ObjectType.sol";
import {SUBMITTED, ACTIVE, KEEP_STATE, DECLINED, CONFIRMED, CLOSED, PAID} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {Version, VersionLib} from "../type/Version.sol";

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";


contract ClaimService is 
    ComponentVerifyingService, 
    IClaimService
{

    IPoolService internal _poolService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing()
    {
        (
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));

        registerInterface(type(IClaimService).interfaceId);
    }

    function submit(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData // claim submission data
    )
        external
        virtual
        returns (ClaimId claimId)
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check policy is in its active period
        if(policyInfo.activatedAt.eqz() || TimestampLib.blockTimestamp() >= policyInfo.expiredAt) {
            revert ErrorClaimServicePolicyNotOpen(policyNftId);
        }

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
            IPolicy.ClaimInfo(
                claimAmount,
                AmountLib.zero(), // paidAmount
                0, // payoutsCount
                0, // openPayoutsCount
                claimData, // claim submission data
                "", // claim processing data
                TimestampLib.zero())); // closedAt

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
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // check/update claim info
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.claimAmount = confirmedAmount;
        claimInfo.processData = data;
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());

        // update and save policy info with instance
        policyInfo.claimAmount = policyInfo.claimAmount + confirmedAmount;
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);
    }

    function decline(
        NftId policyNftId, 
        ClaimId claimId,
        bytes memory data // claim processing data
    )
        external
        virtual
    {
        (
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

    function close(
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
    {
        (
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


    function createPayout(
        NftId policyNftId, 
        ClaimId claimId,
        Amount amount,
        bytes memory data
    )
        external
        returns (PayoutId payoutId)
    {
        (
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
        uint8 claimNo = claimInfo.payoutsCount + 1;
        payoutId = PayoutIdLib.toPayoutId(claimId, claimNo);
        instance.getInstanceStore().createPayout(
            policyNftId, 
            payoutId, 
            IPolicy.PayoutInfo(
                payoutId.toClaimId(),
                amount,
                data,
                TimestampLib.zero()));

        // update and save claim info with instance
        claimInfo.payoutsCount += 1;
        claimInfo.openPayoutsCount += 1;
        instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());

        // update and save policy info with instance
        policyInfo.payoutAmount.add(amount);
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServicePayoutCreated(policyNftId, payoutId, amount);
    }


    function processPayout(
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
    {
        (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        ) = _verifyCallerWithPolicy(policyNftId);

        // TODO add check that payout exists and is open
        IPolicy.PayoutInfo memory payoutInfo = instanceReader.getPayoutInfo(policyNftId, payoutId);

        // update and save payout info with instance
        payoutInfo.paidAt = TimestampLib.blockTimestamp();
        instance.getInstanceStore().updatePayout(policyNftId, payoutId, payoutInfo, PAID());

        // TODO update and save claim info with instance
        ClaimId claimId = payoutId.toClaimId();
        Amount payoutAmount = payoutInfo.amount;
        IPolicy.ClaimInfo memory claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
        claimInfo.paidAmount = claimInfo.paidAmount.add(payoutAmount);
        claimInfo.openPayoutsCount -= 1;

        // check if this payout is closing the linked claim
        // update claim and policy info accordingly
        if(claimInfo.openPayoutsCount == 0 && claimInfo.paidAmount == claimInfo.claimAmount) {
            claimInfo.closedAt == TimestampLib.blockTimestamp();
            instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, CLOSED());

            policyInfo.openClaimsCount -= 1;
        } else {
            instance.getInstanceStore().updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
        }

        // update and save policy info with instance
        policyInfo.payoutAmount = policyInfo.payoutAmount.add(payoutAmount);
        instance.getInstanceStore().updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // inform pool about payout
        _poolService.reduceCollateral(
            instance, 
            address(instanceReader.getComponentInfo(policyInfo.productNftId).token),
            policyNftId, 
            policyInfo, 
            payoutAmount);

        // transfer payout token and fee
        (
            Amount netPayoutAmount,
            address beneficiary
        ) = _transferPayoutAmount(
            instanceReader,
            policyNftId,
            policyInfo,
            payoutInfo);

        // TODO callback IPolicyHolder

        emit LogClaimServicePayoutProcessed(policyNftId, payoutId, payoutAmount, beneficiary, netPayoutAmount);
    }

    // TODO create (I)TreasuryService that deals with all gif related token transfers
    function _transferPayoutAmount(
        InstanceReader instanceReader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        IPolicy.PayoutInfo memory payoutInfo
    )
        internal
        returns (
            Amount netPayoutAmount,
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
            beneficiary = _getBeneficiary(policyNftId, payoutInfo.claimId);

            IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
            if(FeeLib.gtz(productInfo.processingFee)) {
                // TODO calculate net payout and processing fees
                // TODO transfer processing fees to product wallet
                // TODO inform product to update fee book keeping
            }

            poolInfo.tokenHandler.transfer(
                poolInfo.wallet,
                beneficiary,
                netPayoutAmount);
        }
    }

    // internal functions

    function _getBeneficiary(
        NftId policyNftId,
        ClaimId claimId
    )
        internal
        returns (address beneficiary)
    {
        // TODO check if owner is IPolicyHolder
        // if so, obtain beneficiary from this contract

        // default beneficiary is policy nft owner
        beneficiary = getRegistry().ownerOf(policyNftId);
    }


    function _verifyCallerWithPolicy(
        NftId policyNftId
    )
        internal
        view
        virtual
        returns (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        NftId productNftId;
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


    function _getDomain() internal pure override returns(ObjectType) {
        return CLAIM();
    }
}