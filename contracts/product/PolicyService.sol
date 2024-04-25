// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";
import {Product} from "./Product.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ClaimId, ClaimIdLib} from "../type/ClaimId.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {ObjectType, APPLICATION, COMPONENT, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE, CLAIM, PRICE} from "../type/ObjectType.sol";
import {APPLIED, COLLATERALIZED, ACTIVE, KEEP_STATE, CLOSED, DECLINED, CONFIRMED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {ReferralId} from "../type/Referral.sol";
import {StateId} from "../type/StateId.sol";
import {VersionPart} from "../type/Version.sol";

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";

contract PolicyService is
    ComponentVerifyingService, 
    IPolicyService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IApplicationService internal _applicationService;
    IComponentService internal _componentService;
    IBundleService internal _bundleService;
    IClaimService internal _claimService;
    IDistributionService internal _distributionService;
    IPoolService internal _poolService;
    IPricingService internal _pricingService;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer
    {
        (
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        VersionPart majorVersion = getVersion().toMajorPart();
        _applicationService = IApplicationService(getRegistry().getServiceAddress(APPLICATION(), majorVersion));
        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), majorVersion));
        _componentService = IComponentService(getRegistry().getServiceAddress(COMPONENT(), majorVersion));
        _claimService = IClaimService(getRegistry().getServiceAddress(CLAIM(), majorVersion));
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), majorVersion));
        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), majorVersion));
        _pricingService = IPricingService(getRegistry().getServiceAddress(PRICE(), majorVersion));

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyActiveComponent(PRODUCT());
        product = Product(productInfo.objectAddress);
    }


    function decline(
        NftId policyNftId
    )
        external
        override
    {
        revert();
    }

    event LogDebug(uint idx, string message);

    /// @dev underwites application which includes the locking of the required collateral from the pool.
    function collateralize(
        NftId applicationNftId, // = policyNftId
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        external 
        virtual override
    {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy is in state applied
        if (instanceReader.getPolicyState(applicationNftId) != APPLIED()) {
            revert ErrorPolicyServicePolicyStateNotApplied(applicationNftId);
        }

        // check policy matches with calling product
        IPolicy.PolicyInfo memory applicationInfo = instanceReader.getPolicyInfo(applicationNftId);
        if(applicationInfo.productNftId != productNftId) {
            revert ErrorPolicyServicePolicyProductMismatch(
                applicationNftId, 
                applicationInfo.productNftId, 
                productNftId);
        }
        
        StateId newPolicyState = COLLATERALIZED();

        // actual collateralizaion
        (
            Amount localCollateralAmount,
            Amount totalCollateralAmount
        ) = _poolService.lockCollateral(
            instance,
            productNftId,
            applicationNftId,
            applicationInfo.bundleNftId,
            applicationInfo.sumInsuredAmount);

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            applicationInfo.activatedAt = activateAt;
            applicationInfo.expiredAt = activateAt.addSeconds(applicationInfo.lifetime);
        }

        // optional collection of premium
        if(requirePremiumPayment) {

            // // calculate premium details
            // IPolicy.Premium memory premium = _pricingService.calculatePremium(
            //     applicationInfo.productNftId,
            //     applicationInfo.riskId,
            //     applicationInfo.sumInsuredAmount,
            //     applicationInfo.lifetime,
            //     applicationInfo.applicationData,
            //     applicationInfo.bundleNftId,
            //     applicationInfo.referralId);

            // // update financials for product, distribution, pool and bundle
            // _updateFinancials(
            //     instance,
            //     productNftId,
            //     applicationInfo.bundleNftId,
            //     premium);

            // // token transfer and callacks to distribution and pool service
            // Amount premiumPaidAmount = _collectAndTransferPremium(
            //     instance, 
            //     instanceReader,
            //     productNftId,
            //     applicationNftId, 
            //     applicationInfo.bundleNftId,
            //     applicationInfo.referralId,
            //     premium);

            Amount premiumPaidAmount = _collectPremium(
                instance,
                applicationNftId,
                applicationInfo);

            applicationInfo.premiumPaidAmount = premiumPaidAmount;
        }

        // store updated policy info
        instance.getInstanceStore().updatePolicy(
            applicationNftId, 
            applicationInfo, 
            newPolicyState);

        // TODO add calling pool contract if it needs to validate application

        // TODO: add logging
    }


    function _collectPremium(
        IInstance instance,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo
    )
        internal
        virtual
        returns (
            Amount premiumPaidAmount
        )
    {
        NftId productNftId = applicationInfo.productNftId;

        // calculate premium details
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            applicationInfo.riskId,
            applicationInfo.sumInsuredAmount,
            applicationInfo.lifetime,
            applicationInfo.applicationData,
            applicationInfo.bundleNftId,
            applicationInfo.referralId);

        // update financials for product, distribution, pool and bundle
        _updateFinancials(
            instance,
            productNftId,
            applicationInfo.bundleNftId,
            premium);

        // token transfer and callacks to distribution and pool service
        premiumPaidAmount = _collectAndTransferPremium(
            instance, 
            instance.getInstanceReader(),
            productNftId,
            applicationNftId, 
            applicationInfo.bundleNftId,
            applicationInfo.referralId,
            premium);
    }


    function _collectAndTransferPremium(
        IInstance instance,
        InstanceReader instanceReader,
        NftId productNftId,
        NftId policyNftId,
        NftId bundleNftId,
        ReferralId referralId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
        returns (Amount premiumPaidAmount)
    {
        address policyOwner = getRegistry().ownerOf(policyNftId);
        uint256 premiumAmount = premium.premiumAmount;

        emit LogDebug(21, "before _getTokenHandlerAndWallets");
        // get token handler and target wallets
        (
            TokenHandler tokenHandler,
            NftId distributionNftId,
            address productWallet,
            address distributionWallet,
            address poolWallet
        ) = _getTokenHandlerAndWallets(
            instanceReader, 
            productNftId);

        emit LogDebug(22, "before check balance");
        // check balance
        uint256 balance = tokenHandler.getToken().balanceOf(policyOwner);
        if (balance < premiumAmount) {
            revert ErrorPolicyServiceBalanceInsufficient(policyOwner, premiumAmount, balance);
        }

        emit LogDebug(23, "before check allowance");
        // check allowance
        uint256 allowance = tokenHandler.getToken().allowance(policyOwner, address(tokenHandler));
        if (allowance < premiumAmount) {
            revert ErrorPolicyServiceAllowanceInsufficient(policyOwner, address(tokenHandler), premiumAmount, allowance);
        }

        // transfer funds and inform distribution and pool
        {
            emit LogDebug(24, "before transfer to product wallet");
            // move product fee to product wallet
            tokenHandler.transfer(policyOwner, productWallet, premium.productFeeAmount);

            emit LogDebug(25, "before transfer to distribution wallet");
            // move distribution fee to distribution wallet and do distribution callback 
            tokenHandler.transfer(policyOwner, distributionWallet, premium.distributionFeeAndCommissionAmount);
            _distributionService.processSale(
                distributionNftId, 
                referralId, 
                premium);

            emit LogDebug(26, "before transfer to pool wallet");
            // move net premium, pool fee and bundle fee to pool wallet and do pool callback
            tokenHandler.transfer(policyOwner, poolWallet, premium.poolPremiumAndFeeAmount);
            _poolService.processSale(
                bundleNftId, 
                premium);
        }

        emit LogDebug(27, "before end of _collectAndTransferPremium");
        return AmountLib.toAmount(premium.premiumAmount);
    }


    function _updateFinancials(
        IInstance instance,
        NftId productNftId,
        NftId bundleNftId,
        IPolicy.Premium memory premium
    )
        internal
        virtual
    {
        // fees
        Amount productFeeAmount = AmountLib.toAmount(
            premium.productFeeVarAmount + premium.productFeeFixAmount);

        Amount distributionFeeAmount = AmountLib.toAmount(
            premium.productFeeVarAmount + premium.productFeeFixAmount);

        Amount poolFeeAmount = AmountLib.toAmount(
            premium.poolFeeFixAmount + premium.poolFeeVarAmount);

        Amount bundleFeeAmount = AmountLib.toAmount(
            premium.bundleFeeFixAmount + premium.bundleFeeVarAmount);

        // balances
        Amount bundleBalanceAmount = AmountLib.toAmount(premium.netPremiumAmount) + bundleFeeAmount;
        Amount poolBalanceAmount = bundleBalanceAmount + poolFeeAmount;

        InstanceStore instanceStore = instance.getInstanceStore();
        IComponents.ProductInfo memory productInfo = instance.getInstanceReader().getProductInfo(productNftId);
        _componentService.increaseProductFees(instanceStore, productNftId, productFeeAmount);
        _componentService.increaseDistributionFees(instanceStore, productInfo.distributionNftId, distributionFeeAmount);
        _componentService.increasePoolBalance(instanceStore, productInfo.poolNftId, poolBalanceAmount, poolFeeAmount);
        _componentService.increaseBundleBalance(instanceStore, bundleNftId, bundleBalanceAmount, bundleFeeAmount);
    }


    function collectPremium(
        NftId policyNftId, 
        Timestamp activateAt
    )
        external 
        virtual
    {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        StateId stateId = instanceReader.getPolicyState(policyNftId);

        // check policy is in state collateralized or active
        if (!(stateId == COLLATERALIZED() || stateId == ACTIVE())) {
            revert ErrorPolicyServicePolicyStateNotCollateralizedOrApplied(policyNftId);
        }

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        // check if premium is already collected
        if (policyInfo.premiumPaidAmount.gtz()) {
            revert ErrorPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        policyInfo.premiumPaidAmount = _collectPremium(
                instance,
                policyNftId,
                policyInfo);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        if(activateAt.gtz() && policyInfo.activatedAt.eqz()) {
            activate(policyNftId, activateAt);
        }

        // TODO: add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        require(
            policyInfo.activatedAt.eqz(),
            "ERROR:PRS-020:ALREADY_ACTIVATED");

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, ACTIVE());

        // TODO: add logging
    }


    function expire(
        NftId policyNftId
    )
        external
        override
        // solhint-disable-next-line no-empty-blocks
    {
        
    }

    function close(
        NftId policyNftId
    )
        external 
        override
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.activatedAt.eqz()) {
            revert ErrorIPolicyServicePolicyNotActivated(policyNftId);
        }

        StateId state = instanceReader.getPolicyState(policyNftId);
        if (state != ACTIVE()) {
            revert ErrorIPolicyServicePolicyNotActive(policyNftId, state);
        }

        if (policyInfo.closedAt.gtz()) {
            revert ErrorIPolicyServicePolicyAlreadyClosed(policyNftId);
        }

        // TODO consider to allow for underpaid premiums (with the effects of reducing max payouts accordingly)
        if (!(policyInfo.premiumAmount == policyInfo.premiumPaidAmount)) {
            revert ErrorPolicyServicePremiumNotFullyPaid(policyNftId, policyInfo.premiumAmount, policyInfo.premiumPaidAmount);
        }

        if (policyInfo.openClaimsCount > 0) {
            revert ErrorIPolicyServiceOpenClaims(policyNftId, policyInfo.openClaimsCount);
        }

        policyInfo.closedAt = TimestampLib.blockTimestamp();

        _poolService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo);

        instance.getInstanceStore().updatePolicy(policyNftId, policyInfo, CLOSED());
    }


    function _processPremium(
        IInstance instance,
        NftId policyNftId,
        Amount premiumExpectedAmount
    )
        internal
        returns (Amount netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumExpectedAmount.eqz()) {
            return AmountLib.zero();
        }

        NftId productNftId = getRegistry().getObjectInfo(policyNftId).parentNftId;
        IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            policyInfo.riskId,
            policyInfo.sumInsuredAmount,
            policyInfo.lifetime,
            policyInfo.applicationData,
            policyInfo.bundleNftId,
            policyInfo.referralId);

        if (premium.premiumAmount != premiumExpectedAmount.toInt()) {
            revert ErrorPolicyServicePremiumMismatch(
                policyNftId, 
                premiumExpectedAmount, 
                AmountLib.toAmount(premium.premiumAmount));
        }

        address policyOwner = getRegistry().ownerOf(policyNftId);
        (
            TokenHandler tokenHandler,
            NftId distributionNftId,
            address productWallet,
            address distributionWallet,
            address poolWallet
        ) = _getTokenHandlerAndWallets(
            instance.getInstanceReader(), 
            productNftId);

        if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premium.premiumAmount) {
            revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premium.premiumAmount);
        }

        Amount productFeeAmountToTransfer = AmountLib.toAmount(premium.productFeeFixAmount + premium.productFeeVarAmount);
        Amount distributionFeeAmountToTransfer = AmountLib.toAmount(premium.distributionFeeFixAmount + premium.distributionFeeVarAmount - premium.discountAmount);
        Amount poolAmountToTransfer = AmountLib.toAmount(
            premium.netPremiumAmount 
            + premium.poolFeeFixAmount + premium.poolFeeVarAmount 
            + premium.bundleFeeFixAmount + premium.bundleFeeVarAmount);

        netPremiumAmount = AmountLib.toAmount(premium.netPremiumAmount);

        // transfer funds
        {
            // move product fee to product wallet
            tokenHandler.transfer(policyOwner, productWallet, productFeeAmountToTransfer);

            // move distribution fee to distribution wallet
            tokenHandler.transfer(policyOwner, distributionWallet, distributionFeeAmountToTransfer);
            _distributionService.processSale(distributionNftId, policyInfo.referralId, premium);

            // move netpremium, bundleFee and poolFee to pool wallet
            tokenHandler.transfer(policyOwner, poolWallet, poolAmountToTransfer);
            _poolService.processSale(policyInfo.bundleNftId, premium);
        }

        // validate total amount transferred
        {
            Amount totalTransferred = distributionFeeAmountToTransfer + poolAmountToTransfer + productFeeAmountToTransfer;

            if (premium.premiumAmount != totalTransferred.toInt()) {
                revert ErrorPolicyServiceTransferredPremiumMismatch(
                    policyNftId, 
                    AmountLib.toAmount(premium.premiumAmount), 
                    totalTransferred);
            }
        }

        // TODO: add logging
    }

    function _getTokenHandlerAndWallets(
        InstanceReader instanceReader,
        NftId productNftId
    )
        internal
        virtual
        view returns (
            TokenHandler tokenHandler,
            NftId distributionNftId,
            address productWallet,
            address distributionWallet,
            address poolWallet
        )
    {
        IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(productNftId);
        tokenHandler = componentInfo.tokenHandler;
        productWallet = componentInfo.wallet;

        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        distributionNftId = productInfo.distributionNftId;
        distributionWallet = instanceReader.getComponentInfo(distributionNftId).wallet;
        poolWallet = instanceReader.getComponentInfo(productInfo.poolNftId).wallet;
    }
}