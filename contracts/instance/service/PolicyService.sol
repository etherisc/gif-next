// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {Product} from "../../components/Product.sol";
import {IComponents} from "../module/IComponents.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {ISetup} from "../module/ISetup.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";

import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {ObjectType, APPLICATION, DISTRIBUTION, PRODUCT, POOL, POLICY, BUNDLE} from "../../types/ObjectType.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE, KEEP_STATE, CLOSED} from "../../types/StateId.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {StateId} from "../../types/StateId.sol";
import {VersionPart} from "../../types/Version.sol";

import {ComponentService} from "../base/ComponentService.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IPolicyService} from "./IPolicyService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";


contract PolicyService is
    ComponentService, 
    IPolicyService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;

    IPoolService internal _poolService;
    IBundleService internal _bundleService;
    IApplicationService internal _applicationService;
    IDistributionService internal _distributionService;

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

        initializeService(registryAddress, address(0), owner);

        VersionPart majorVersion = getVersion().toMajorPart();
        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), majorVersion));
        _bundleService = IBundleService(getRegistry().getServiceAddress(BUNDLE(), majorVersion));
        _applicationService = IApplicationService(getRegistry().getServiceAddress(APPLICATION(), majorVersion));
        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), majorVersion));

        registerInterface(type(IPolicyService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return POLICY();
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }

    // function _getAndVerifyUnderwritingSetup(
    //     IInstance instance,
    //     InstanceReader instanceReader,
    //     IPolicy.PolicyInfo memory policyInfo,
    //     ISetup.ProductSetupInfo memory productSetupInfo
    // )
    //     internal
    //     view
    //     returns (
    //         NftId poolNftId,
    //         IComponents.PoolInfo memory poolInfo,
    //         NftId bundleNftId,
    //         IBundle.BundleInfo memory bundleInfo
    //     )
    // {
    //     // check match between policy and bundle (via pool)
    //     poolNftId = productSetupInfo.poolNftId;
    //     bundleNftId = policyInfo.bundleNftId;
    //     bundleInfo = instanceReader.getBundleInfo(bundleNftId);
    //     require(bundleInfo.poolNftId == poolNftId, "BUNDLE_POOL_MISMATCH");

    //     // calculate required collateral
    //     IComponents.ComponentInfo memory componentInfo = instanceReader.getComponentInfo(poolNftId);
    //     poolInfo = abi.decode(componentInfo.data, (IComponents.PoolInfo));
    // }


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
        (NftId productNftId,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();

        // check policy matches with calling product
        IPolicy.PolicyInfo memory applicationInfo = instanceReader.getPolicyInfo(applicationNftId);
        require(applicationInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");

        // check policy is in state applied
        require(instanceReader.getPolicyState(applicationNftId) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");
        
        StateId newPolicyState = UNDERWRITTEN();

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            newPolicyState = ACTIVE();
            applicationInfo.activatedAt = activateAt;
            applicationInfo.expiredAt = activateAt.addSeconds(applicationInfo.lifetime);
        }

        // lock bundle collateral
        uint256 netPremiumAmount = 0; // > 0 if immediate premium payment 

        // optional collection of premium
        if(requirePremiumPayment) {
            netPremiumAmount = _processPremiumByTreasury(
                instance, 
                applicationNftId, 
                applicationInfo.premiumAmount);

            applicationInfo.premiumPaidAmount += applicationInfo.premiumAmount;
        }

        // store updated policy info
        instance.updatePolicy(applicationNftId, applicationInfo, newPolicyState);

        // lock collateral and update pool and bundle book keeping
        // pool retention level: fraction of sum insured that product will cover from pool funds directly
        // eg retention level 30%, payouts up to 30% of the sum insured will be made from the product's pool directly
        // for the remaining 70% the pool owns a policy that will cover claims that exceed the 30% of the sum insured
        // might also call pool component (for isVerifyingApplications pools)
        _poolService.lockCollateral(
            instance,
            productNftId,
            applicationNftId, 
            applicationInfo,
            netPremiumAmount); // for pool book keeping (fee + additional capital)

        // TODO: add logging
    }


    function calculateRequiredCollateral(UFixed collateralizationLevel, uint256 sumInsuredAmount) public pure override returns(uint256 collateralAmount) {
        UFixed sumInsuredUFixed = UFixedLib.toUFixed(sumInsuredAmount);
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredUFixed;
        return collateralUFixed.toInt();
    } 

    function collectPremium(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (NftId productNftId,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IPolicy.PolicyInfo memory policyInfo = instanceReader.getPolicyInfo(policyNftId);

        if (policyInfo.premiumPaidAmount == policyInfo.premiumAmount) {
            revert ErrorIPolicyServicePremiumAlreadyPaid(policyNftId, policyInfo.premiumPaidAmount);
        }

        uint256 unpaidPremiumAmount = policyInfo.premiumAmount - policyInfo.premiumPaidAmount;

        uint256 netPremiumAmount = _processPremiumByTreasury(
                instance, 
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
        (,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
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
        (,, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
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

        _poolService.releaseCollateral(
            instance, 
            policyNftId, 
            policyInfo);

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
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
        returns (uint256 netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumAmount > 0) {
            NftId productNftId = getRegistry().getObjectInfo(policyNftId).parentNftId;
            ISetup.ProductSetupInfo memory productSetupInfo = instance.getInstanceReader().getProductSetupInfo(productNftId);
            IPolicy.PolicyInfo memory policyInfo = instance.getInstanceReader().getPolicyInfo(policyNftId);
            TokenHandler tokenHandler = productSetupInfo.tokenHandler;
            address policyOwner = getRegistry().ownerOf(policyNftId);
            address poolWallet = instance.getInstanceReader().getComponentInfo(productSetupInfo.poolNftId).wallet;
            IPolicy.Premium memory premium = _applicationService.calculatePremium(
                productNftId,
                policyInfo.riskId,
                policyInfo.sumInsuredAmount,
                policyInfo.lifetime,
                policyInfo.applicationData,
                policyInfo.bundleNftId,
                policyInfo.referralId
                );

            if (premium.premiumAmount != premiumAmount) {
                revert ErrorIPolicyServicePremiumMismatch(policyNftId, premiumAmount, premium.premiumAmount);
            }

            // move product fee to product wallet
            address productWallet = productSetupInfo.wallet;
            if (tokenHandler.getToken().allowance(policyOwner, address(tokenHandler)) < premium.premiumAmount) {
                revert ErrorIPolicyServiceInsufficientAllowance(policyOwner, address(tokenHandler), premium.premiumAmount);
            }
            tokenHandler.transfer(policyOwner, productWallet, premium.productFeeFixAmount + premium.productFeeVarAmount);

            // move distribution fee to distribution wallet
            ISetup.DistributionSetupInfo memory distributionSetupInfo = instance.getInstanceReader().getDistributionSetupInfo(productSetupInfo.distributionNftId);
            address distributionWallet = distributionSetupInfo.wallet;
            uint256 distributionFeeAmountToTransfer = premium.distributionFeeFixAmount + premium.distributionFeeVarAmount - premium.discountAmount;
            tokenHandler.transfer(policyOwner, distributionWallet, distributionFeeAmountToTransfer);
            _distributionService.processSale(productSetupInfo.distributionNftId, policyInfo.referralId, premium, distributionFeeAmountToTransfer);
            
            // move netpremium to pool wallet
            tokenHandler.transfer(policyOwner, poolWallet, premium.netPremiumAmount);
            
            // TODO: move pool related tokens too
            // TODO: move bundle related tokens too
            netPremiumAmount = premium.netPremiumAmount;
        }

        // TODO: add logging
    }
}
