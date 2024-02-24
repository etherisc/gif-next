// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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

import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, POLICY, BUNDLE} from "../../types/ObjectType.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE, KEEP_STATE, CLOSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Version, VersionLib} from "../../types/Version.sol";
//import {RoleId, PRODUCT_OWNER_ROLE} from "../../types/RoleId.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPoolService} from "./IPoolService.sol";
import {IBundleService} from "./IBundleService.sol";


contract PolicyService is ComponentServiceBase, IPolicyService {
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IPoolService internal _poolService;
    IBundleService internal _bundleService;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        _initializeService(registryAddress, owner);

        _poolService = IPoolService(_registry.getServiceAddress(POOL(), getMajorVersion()));
        _bundleService = IBundleService(_registry.getServiceAddress(BUNDLE(), getMajorVersion()));

        _registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override(IService, Service) returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }
    // TODO: no access restrictions
    function calculatePremium(
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        public
        view 
        override
        returns (
            uint256 premiumAmount,
            uint256 productFeeAmount,
            uint256 poolFeeAmount,
            uint256 bundleFeeAmount,
            uint256 distributionFeeAmount
        )
    {
        Product product = _getAndVerifyInstanceAndProduct();
        uint256 netPremiumAmount = product.calculateNetPremium(
            sumInsuredAmount,
            riskId,
            lifetime,
            applicationData
        );

        (
            productFeeAmount,
            poolFeeAmount,
            bundleFeeAmount,
            distributionFeeAmount
        ) = _calculateFeeAmounts(
            netPremiumAmount,
            product,
            bundleNftId,
            referralId
        );

        premiumAmount = netPremiumAmount + productFeeAmount;
        premiumAmount += poolFeeAmount + bundleFeeAmount;
        premiumAmount += distributionFeeAmount;
    }

    function _calculateFeeAmounts(
        uint256 netPremiumAmount,
        Product product,
        NftId bundleNftId,
        ReferralId referralId
    )
        internal
        view
        returns (
            uint256 productFeeAmount,
            uint256 poolFeeAmount,
            uint256 bundleFeeAmount,
            uint256 distributionFeeAmount
        )
    {
        InstanceReader instanceReader;
        {
            IInstance instance = product.getInstance();
            instanceReader = instance.getInstanceReader();
        }
        
        NftId poolNftId = product.getPoolNftId();
        IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId == poolNftId,"ERROR:PRS-035:BUNDLE_POOL_MISMATCH");

        {
            ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(product.getProductNftId());
            (productFeeAmount,) = FeeLib.calculateFee(productSetupInfo.productFee, netPremiumAmount);
        }
        {
            ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
            (poolFeeAmount,) = FeeLib.calculateFee(poolSetupInfo.poolFee, netPremiumAmount);
        }
        {
            NftId distributionNftId = product.getDistributionNftId();
            ISetup.DistributionSetupInfo memory distributionSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
            (distributionFeeAmount,) = FeeLib.calculateFee(distributionSetupInfo.distributionFee, netPremiumAmount);
        }
        
        (bundleFeeAmount,) = FeeLib.calculateFee(bundleInfo.fee, netPremiumAmount);
    }


    function createApplication(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) external override returns (NftId policyNftId) {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        // TODO: add validations (see create bundle in pool service)

        policyNftId = getRegistryService().registerPolicy(
            IRegistry.ObjectInfo(
                zeroNftId(),
                productInfo.nftId,
                POLICY(),
                false, // intercepting property for policies is defined on product
                address(0),
                applicationOwner,
                ""
            )
        );

        (uint256 premiumAmount,,,,) = calculatePremium(
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        IPolicy.PolicyInfo memory policyInfo = IPolicy.PolicyInfo(
            productInfo.nftId,
            bundleNftId,
            referralId,
            riskId,
            sumInsuredAmount,
            premiumAmount,
            0,
            lifetime,
            applicationData,
            "",
            0,
            0,
            0,
            zeroTimestamp(),
            zeroTimestamp(),
            zeroTimestamp()
        );
        
        instance.createPolicy(policyNftId, policyInfo);
        instance.updatePolicyState(policyNftId, APPLIED());

        // TODO: add logging
    }

    function _getAndVerifyUnderwritingSetup(
        IInstance instance,
        InstanceReader instanceReader,
        IPolicy.PolicyInfo memory policyInfo,
        ISetup.ProductSetupInfo memory productSetupInfo
    )
        internal
        view
        returns (
            NftId bundleNftId,
            IBundle.BundleInfo memory bundleInfo,
            uint256 collateralAmount
        )
    {
        // check match between policy and bundle (via pool)
        bundleNftId = policyInfo.bundleNftId;
        bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId == productSetupInfo.poolNftId, "POLICY_BUNDLE_MISMATCH");

        // calculate required collateral
        NftId poolNftId = productSetupInfo.poolNftId;
        ISetup.PoolSetupInfo memory poolInfo = instanceReader.getPoolSetupInfo(poolNftId);

        // obtain remaining return values
        collateralAmount = calculateRequiredCollateral(poolInfo.collateralizationLevel, policyInfo.sumInsuredAmount);
    }

    function _lockCollateralInBundle(
        IInstance instance,
        NftId bundleNftId, 
        IBundle.BundleInfo memory bundleInfo,
        NftId policyNftId, 
        uint256 collateralAmount
    )
        internal
        returns (IBundle.BundleInfo memory)
    {
        bundleInfo.lockedAmount += collateralAmount;
        // TODO: track policy associated to bundle in bundlemanager (tbd) and how much is locked for it
        return bundleInfo;
    }

    function _underwriteByPool(
        NftId poolNftId,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        bytes memory bundleFilter,
        uint256 collateralAmount
    )
        internal
    {
        address poolAddress = getRegistry().getObjectInfo(poolNftId).objectAddress;
        IPoolComponent pool = IPoolComponent(poolAddress);
        pool.underwrite(
            policyNftId, 
            policyInfo.applicationData, 
            bundleFilter,
            collateralAmount);
    }


    function revoke(
        NftId policyNftId
    )
        external
        override
    {
        require(false, "ERROR:PRS-234:NOT_YET_IMPLEMENTED");
    }


    function underwrite(
        NftId policyNftId,
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        external 
        override
    {
        // check caller is registered product
        (
            IRegistry.ObjectInfo memory productInfo, 
            IInstance instance
        ) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check match between policy and calling product
        NftId productNftId = productInfo.nftId;
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);
        require(policyInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");
        require(instanceReader.getPolicyState(policyNftId) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");

        NftId bundleNftId;
        IBundle.BundleInfo memory bundleInfo;
        uint256 collateralAmount;
        uint256 netPremiumAmount = 0; // > 0 if immediate premium payment 
        {
            ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
            IBundle.BundleInfo memory bundleInfo;
            
            (
                bundleNftId,
                bundleInfo,
                collateralAmount
            ) = _getAndVerifyUnderwritingSetup(
                instance,
                instanceReader,
                policyInfo,
                productSetupInfo
            );
        }
        
        // lock bundle collateral
        bundleInfo = _lockCollateralInBundle(
            instance,
            bundleNftId,
            bundleInfo,
            policyNftId, 
            collateralAmount);
        StateId newPolicyState = UNDERWRITTEN();
        
        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            policyInfo.activatedAt = activateAt;
            policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);
        }

        // optional collection of premium
        if(requirePremiumPayment) {
            netPremiumAmount = _processPremiumByTreasury(
                instance, 
                productInfo.nftId,
                policyNftId, 
                policyInfo.premiumAmount);

            policyInfo.premiumPaidAmount += policyInfo.premiumAmount;
        }

        _bundleService.underwritePolicy(instance, policyNftId, bundleNftId, collateralAmount, netPremiumAmount);
        instance.updatePolicy(policyNftId, policyInfo, newPolicyState);

        // involve pool if necessary
        {
            ISetup.PoolSetupInfo memory poolInfo = instanceReader.getPoolSetupInfo(bundleInfo.poolNftId);

            if(poolInfo.isConfirmingApplication) {
                _underwriteByPool(
                    bundleInfo.poolNftId,
                    policyNftId,
                    policyInfo,
                    bundleInfo.filter,
                    collateralAmount
                );
            }
        }

        // TODO: add logging
    }

    function calculateRequiredCollateral(UFixed collateralizationLevel, uint256 sumInsuredAmount) public pure override returns(uint256 collateralAmount) {
        UFixed sumInsuredUFixed = UFixedLib.toUFixed(sumInsuredAmount);
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredUFixed;
        return collateralUFixed.toInt();
    } 

    function collectPremium(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.premiumPaidAmount == policyInfo.premiumAmount) {
            revert ErrorIPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        uint256 unpaidPremiumAmount = policyInfo.premiumAmount - policyInfo.premiumPaidAmount;

        uint256 netPremiumAmount = _processPremiumByTreasury(
                instance, 
                productInfo.nftId,
                policyNftId, 
                unpaidPremiumAmount);

        policyInfo.premiumPaidAmount += unpaidPremiumAmount;

        _bundleService.increaseBalance(instance, policyInfo.bundleNftId, netPremiumAmount);
        instance.updatePolicy(policyNftId, policyInfo, KEEP_STATE());

        if(activateAt.gtz() && policyInfo.activatedAt.eqz()) {
            activate(policyNftId, activateAt);
        }

        // TODO: add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) public override {
        // check caller is registered product
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        require(
            policyInfo.activatedAt.eqz(),
            "ERROR:PRS-020:ALREADY_ACTIVATED");

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        instance.updatePolicy(policyNftId, policyInfo, ACTIVE());

        // TODO: add logging
    }

    function close(
        NftId policyNftId
    ) external override // solhint-disable-next-line no-empty-blocks
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
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

        if (policyInfo.premiumAmount != policyInfo.premiumPaidAmount) {
            revert ErrorIPolicyServicePremiumNotFullyPaid(policyNftId, policyInfo.premiumAmount, policyInfo.premiumPaidAmount);
        }

        if (policyInfo.openClaimsCount > 0) {
            revert ErrorIPolicyServiceOpenClaims(policyNftId, policyInfo.openClaimsCount);
        }

        if (TimestampLib.blockTimestamp().lte(policyInfo.expiredAt) && (policyInfo.payoutAmount < policyInfo.sumInsuredAmount)) {
            revert ErrorIPolicyServicePolicyHasNotExpired(policyNftId, policyInfo.expiredAt);
        }

        policyInfo.closedAt = TimestampLib.blockTimestamp();

        _bundleService.closePolicy(instance, policyNftId, policyInfo.bundleNftId, policyInfo.sumInsuredAmount);
        instance.updatePolicy(policyNftId, policyInfo, CLOSED());
    }

    function _getPoolNftId(
        IInstance instance,
        NftId productNftId
    )
        internal
        view
        returns (NftId poolNftid)
    {
        InstanceReader instanceReader = instance.getInstanceReader();
        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        return productSetupInfo.poolNftId;
    }


    function _processPremiumByTreasury(
        IInstance instance,
        NftId productNftId,
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
        returns (uint256 netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumAmount > 0) {
            ISetup.ProductSetupInfo memory productSetupInfo = instance.getInstanceReader().getProductSetupInfo(productNftId);
            TokenHandler tokenHandler = productSetupInfo.tokenHandler;
            address policyOwner = getRegistry().ownerOf(policyNftId);
            ISetup.PoolSetupInfo memory poolSetupInfo = instance.getInstanceReader().getPoolSetupInfo(productSetupInfo.poolNftId);
            address poolWallet = poolSetupInfo.wallet;
            netPremiumAmount = premiumAmount;
            Fee memory productFee = productSetupInfo.productFee;

            if (FeeLib.feeIsZero(productFee)) {
                tokenHandler.transfer(
                    policyOwner,
                    poolWallet,
                    premiumAmount
                );
            } else {
                (uint256 productFeeAmount, uint256 netAmount) = FeeLib.calculateFee(productSetupInfo.productFee, netPremiumAmount);
                address productWallet = productSetupInfo.wallet;
                if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premiumAmount) {
                    revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premiumAmount);
                }
                tokenHandler.transfer(policyOwner, productWallet, productFeeAmount);
                tokenHandler.transfer(policyOwner, poolWallet, netAmount);
                netPremiumAmount = netAmount;
            }
        }

        // TODO: add logging
    }
}
