// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "./IApplicationService.sol";

import {IComponents} from "../module/IComponents.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {Product} from "../../components/Product.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury} from "../module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {Amount, AmountLib} from "../../types/Amount.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, CLAIM, BUNDLE} from "../../types/ObjectType.sol";
import {SUBMITTED, ACTIVE, KEEP_STATE, DECLINED, CONFIRMED, CLOSED, PAID} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {ClaimId, ClaimIdLib} from "../../types/ClaimId.sol";
import {PayoutId, PayoutIdLib} from "../../types/PayoutId.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {ComponentService} from "../base/ComponentService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IBundleService} from "./IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";


contract ClaimService is 
    ComponentService, 
    IClaimService
{

    IPoolService internal _poolService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        // TODO check this, might no longer be the way, refactor if necessary
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));

        registerInterface(type(IClaimService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return CLAIM();
    }

    function submit(
        NftId policyNftId, 
        Amount claimAmount,
        bytes memory claimData
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
        if(policyInfo.payoutAmount.toInt() + claimAmount.toInt() > policyInfo.sumInsuredAmount) {
            revert ErrorClaimServiceClaimExceedsSumInsured(
                policyNftId, 
                AmountLib.toAmount(policyInfo.sumInsuredAmount), 
                AmountLib.toAmount(policyInfo.payoutAmount.toInt() + claimAmount.toInt()));
        }

        // create new claim
        claimId = ClaimIdLib.toClaimId(policyInfo.claimsCount + 1);
        instance.createClaim(
            policyNftId, 
            claimId, 
            IPolicy.ClaimInfo(
                claimAmount,
                AmountLib.zero(), // paidAmount
                0, // payoutsCount
                0, // openPayoutsCount
                claimData,
                TimestampLib.zero())); // closedAt

        // update and save policy info with instance
        policyInfo.claimsCount += 1;
        policyInfo.openClaimsCount += 1;
        // policy claim amount is only updated when claim is confirmed
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimSubmitted(policyNftId, claimId, claimAmount);
    }


    function confirm(
        NftId policyNftId, 
        ClaimId claimId,
        Amount confirmedAmount
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
        instance.updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());

        // update and save policy info with instance
        policyInfo.claimAmount = policyInfo.claimAmount.add(confirmedAmount);
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimConfirmed(policyNftId, claimId, confirmedAmount);
    }

    function decline(
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
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.updateClaim(policyNftId, claimId, claimInfo, DECLINED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

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
        instance.updateClaim(policyNftId, claimId, claimInfo, CLOSED());

        // update and save policy info with instance
        policyInfo.openClaimsCount -= 1;
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        emit LogClaimServiceClaimClosed(policyNftId, claimId);
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
        instance.createPayout(
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
        instance.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());

        // update and save policy info with instance
        policyInfo.payoutAmount.add(amount);
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

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
        instance.updatePayout(policyNftId, payoutId, payoutInfo, PAID());

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
            instance.updateClaim(policyNftId, claimId, claimInfo, CLOSED());

            policyInfo.openClaimsCount -= 1;
        } else {
            instance.updateClaim(policyNftId, claimId, claimInfo, KEEP_STATE());
        }

        // update and save policy info with instance
        policyInfo.payoutAmount = policyInfo.payoutAmount.add(payoutAmount);
        instance.updatePolicyClaims(policyNftId, policyInfo, KEEP_STATE());

        // inform pool about payout
        _poolService.reduceCollateral(instance, policyNftId, policyInfo, payoutAmount);

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
            ISetup.ProductSetupInfo memory setupInfo = instanceReader.getProductSetupInfo(productNftId);

            // get pool component info from policy or product
            NftId poolNftId = getRegistry().getObjectInfo(policyInfo.bundleNftId).parentNftId;
            IComponents.ComponentInfo memory poolInfo = instanceReader.getComponentInfo(poolNftId);

            netPayoutAmount = payoutAmount;
            beneficiary = _getBeneficiary(policyNftId, payoutInfo.claimId);

            if(FeeLib.gtz(setupInfo.processingFee)) {
                // TODO calculate net payout and processing fees
                // TODO transfer processing fees to product wallet
                // TODO inform product to update fee book keeping
            }

            poolInfo.tokenHandler.transfer(
                poolInfo.wallet,
                beneficiary,
                netPayoutAmount.toInt()
            );
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
        returns (
            IInstance instance,
            InstanceReader instanceReader,
            IPolicy.PolicyInfo memory policyInfo
        )
    {
        NftId productNftId;
        (productNftId,, instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
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

    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }
}
