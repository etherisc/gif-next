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

import {Seconds} from "../../types/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, APPLICATION, INSTANCE, PRODUCT, POOL, POLICY, BUNDLE} from "../../types/ObjectType.sol";
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
import {ComponentService} from "../base/ComponentService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPoolService} from "./IPoolService.sol";
import {IBundleService} from "./IBundleService.sol";


contract PolicyService is
    ComponentService, 
    IPolicyService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IPoolService internal _poolService;
    IBundleService internal _bundleService;
    IApplicationService internal _applicationService;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer
    {
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, owner);

        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getMajorVersion()));
        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), getMajorVersion()));
        _applicationService = IApplicationService(getRegistry().getServiceAddress(APPLICATION(), getMajorVersion()));

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override(IService, Service) returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
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
            NftId poolNftId,
            NftId bundleNftId,
            IBundle.BundleInfo memory bundleInfo,
            uint256 collateralAmount
        )
    {
        // check match between policy and bundle (via pool)
        poolNftId = productSetupInfo.poolNftId;
        bundleNftId = policyInfo.bundleNftId;
        bundleInfo = instanceReader.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId == poolNftId, "POLICY_BUNDLE_MISMATCH");

        // calculate required collateral
        ISetup.PoolSetupInfo memory poolInfo = instanceReader.getPoolSetupInfo(poolNftId);

        // obtain remaining return values
        // TODO required collateral amount should be calculated by pool service, not policy service
        collateralAmount = calculateRequiredCollateral(poolInfo.collateralizationLevel, policyInfo.sumInsuredAmount);
    }


    function decline(
        NftId policyNftId
    )
        external
        override
    {
        require(false, "ERROR:PRS-235:NOT_YET_IMPLEMENTED");
    }


    /// @dev underwites application which includes the locking of the required collateral from the pool.
    function underwrite(
        NftId applicationNftId, // = policyNftId
        bool requirePremiumPayment,
        Timestamp activateAt
    )
        external 
        virtual override
    {
        // check caller is registered product
        IInstance instance;
        InstanceReader instanceReader;
        NftId productNftId;
        {
            IRegistry.ObjectInfo memory productInfo;
            (productInfo, instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
            instanceReader = instance.getInstanceReader();
            productNftId = productInfo.nftId;
        }

        // check policy matches with calling product
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(applicationNftId);
        require(policyInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");

        // check policy is in state applied
        require(instanceReader.getPolicyState(applicationNftId) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");
        
        (
            NftId poolNftId,
            NftId bundleNftId,
            IBundle.BundleInfo memory bundleInfo,
            uint256 collateralAmount
        ) = _getAndVerifyUnderwritingSetup(
            instance,
            instanceReader,
            policyInfo,
            instanceReader.getProductSetupInfo(productNftId)
        );
        
        StateId newPolicyState = UNDERWRITTEN();

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            policyInfo.activatedAt = activateAt;
            policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);
        }

        // lock bundle collateral
        uint256 netPremiumAmount = 0; // > 0 if immediate premium payment 

        // optional collection of premium
        if(requirePremiumPayment) {
            netPremiumAmount = _processPremiumByTreasury(
                instance, 
                productNftId,
                applicationNftId, 
                policyInfo.premiumAmount);

            policyInfo.premiumPaidAmount += policyInfo.premiumAmount;
        }

        // lock collateral and update bundle book keeping
        // TODO introduct indirection via pool service?
        // well pool would only need to be involved when a part of the collateral
        // is provided by a "re insurance policy" of the pool
        // but then again the policiy would likely best be attached to the bundle. really? why?
        // retention level: fraction of sum insured that product will cover from pool funds directly
        // eg retention level 30%, payouts up to 30% of the sum insured will be made from the product's pool directly
        // for the remaining 70% the pool owns a policy that will cover claims that exceed the 30% of the sum insured
        // open points:
        // - do we need a link of a bundle to this policy or is it enough to know that the pool has an active policy?
        // - when to buy such policies and for which amount? manual trigger or link to bundle creation and/or funding?
        bundleInfo = _bundleService.lockCollateral(
            instance,
            applicationNftId, 
            bundleNftId,
            collateralAmount,
            netPremiumAmount);

        instance.updatePolicy(applicationNftId, policyInfo, newPolicyState);

        // also verify/confirm application by pool if necessary
        if(instanceReader.getPoolSetupInfo(poolNftId).isVerifyingApplications) {
            IPoolComponent pool = IPoolComponent(
                getRegistry().getObjectInfo(poolNftId).objectAddress);

            pool.verifyApplication(
                applicationNftId, 
                policyInfo.applicationData, 
                bundleNftId,
                bundleInfo.filter,
                collateralAmount);
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
            IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
            TokenHandler tokenHandler = productSetupInfo.tokenHandler;
            address policyOwner = getRegistry().ownerOf(policyNftId);
            ISetup.PoolSetupInfo memory poolSetupInfo = instance.getInstanceReader().getPoolSetupInfo(productSetupInfo.poolNftId);
            address poolWallet = poolSetupInfo.wallet;
            IPolicy.Premium memory premium = _applicationService.calculatePremium(
                productNftId,
                policyInfo.riskId,
                policyInfo.sumInsuredAmount,
                policyInfo.lifetime,
                policyInfo.applicationData,
                policyInfo.bundleNftId,
                policyInfo.referralId
                );

            // if (FeeLib.feeIsZero(premium.productFeeAmount)) {
            //     tokenHandler.transfer(
            //         policyOwner,
            //         poolWallet,
            //         premiumAmount
            //     );
            // } else {
                address productWallet = productSetupInfo.wallet;
                if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premium.premiumAmount) {
                    revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premium.premiumAmount);
                }
                tokenHandler.transfer(policyOwner, productWallet, premium.productFeeFixAmount + premium.productFeeVarAmount);
                tokenHandler.transfer(policyOwner, poolWallet, premium.netPremiumAmount);
                netPremiumAmount = premium.netPremiumAmount;
                // TODO: also move distribution tokens to distribution wallet and call `Distribution.processSale` to update distribution balances
            // }
            // TODO: move pool/bundle related tokens too

        }

        // TODO: add logging
    }
}
