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

import {Timestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POLICY} from "../../types/ObjectType.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE, KEEP_STATE} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IProductService} from "./IProductService.sol";
import {InstanceReader} from "../InstanceReader.sol";

string constant PRODUCT_SERVICE_NAME = "ProductService";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is ComponentServiceBase, IProductService {
    using NftIdLib for NftId;

    string public constant NAME = "ProductService";

    address internal _registryAddress;

    event LogProductServiceSender(address sender);

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner = address(0);
        (_registryAddress, initialOwner) = abi.decode(data, (address, address));

        _initializeService(_registryAddress, owner);

        _registerInterface(type(IService).interfaceId);
        _registerInterface(type(IProductService).interfaceId);
    }


    function getName() public pure override(IService, Service) returns(string memory name) {
        return NAME;
    }

    function _finalizeComponentRegistration(NftId componentNftId, bytes memory initialObjData, IInstance instance) internal override {
        ISetup.ProductSetupInfo memory initialSetup = abi.decode(
            initialObjData,
            (ISetup.ProductSetupInfo)
        );
        instance.createProductSetup(componentNftId, initialSetup);
    }

    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId productNftId = productInfo.nftId;

        ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(productNftId);
        productSetupInfo.productFee = productFee;
        productSetupInfo.processingFee = processingFee;
        
        instance.updateProductSetup(productNftId, productSetupInfo, KEEP_STATE());
    }

    // FIXME: this
    function createRisk(
        RiskId riskId,
        bytes memory data
    ) external override {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        NftId productNftId = productInfo.nftId;
        IRisk.RiskInfo memory riskInfo = IRisk.RiskInfo(productNftId, data);
        instance.createRisk(
            riskId,
            riskInfo
        );
    }

    function updateRisk(
        RiskId riskId,
        bytes memory data
    ) external {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        InstanceReader instanceReader = instance.getInstanceReader();
        IRisk.RiskInfo memory riskInfo = instanceReader.getRiskInfo(riskId);
        riskInfo.data = data;
        instance.updateRisk(riskId, riskInfo, KEEP_STATE());
    }

    function updateRiskState(
        RiskId riskId,
        StateId state
    ) external {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        instance.updateRiskState(riskId, state);
    }

    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }

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
        IInstance instance = product.getInstance();
        // FIXME: this
        // ITreasury.TreasuryInfo memory treasuryInfo = instance.getTreasuryInfo(product.getNftId());
        // IBundle.BundleInfo memory bundleInfo = instance.getBundleInfo(bundleNftId);
        // require(bundleInfo.poolNftId == treasuryInfo.poolNftId,"ERROR:PRS-035:BUNDLE_POOL_MISMATCH");

        // (productFeeAmount,) = FeeLib.calculateFee(treasuryInfo.productFee, netPremiumAmount);
        // (poolFeeAmount,) = FeeLib.calculateFee(treasuryInfo.poolFee, netPremiumAmount);
        // (bundleFeeAmount,) = FeeLib.calculateFee(bundleInfo.fee, netPremiumAmount);

        // IRegistry.ObjectInfo memory distributionInfo = getRegistry().getObjectInfo(treasuryInfo.distributionNftId);
        // IDistributionComponent distribution = IDistributionComponent(distributionInfo.objectAddress);
        // distributionFeeAmount = distribution.calculateFeeAmount(referralId, netPremiumAmount);
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
        // TODO add validations (see create bundle in pool service)

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

        // FIXME: this
        // instance.createPolicyInfo(
        //     policyNftId,
        //     productInfo.nftId,
        //     referralId,
        //     riskId,
        //     sumInsuredAmount,
        //     premiumAmount,
        //     lifetime,
        //     bundleNftId
        // );

        // TODO add logging
    }

    function _getAndVerifyUnderwritingSetup(
        IInstance instance,
        IPolicy.PolicyInfo memory policyInfo
    )
        internal
        view
        returns (
            ITreasury.TreasuryInfo memory treasuryInfo,
            NftId bundleNftId,
            IBundle.BundleInfo memory bundleInfo,
            uint256 collateralAmount
        )
    {
        // FIXME: this
        // check match between policy and bundle (via pool)
        // treasuryInfo = instance.getTreasuryInfo(policyInfo.productNftId);
        // bundleNftId = policyInfo.bundleNftId;
        // bundleInfo = instance.getBundleInfo(bundleNftId);
        // require(bundleInfo.poolNftId == treasuryInfo.poolNftId, "POLICY_BUNDLE_MISMATCH");

        // // calculate required collateral
        // NftId poolNftId = treasuryInfo.poolNftId;
        // ISetup.PoolSetupInfo memory poolInfo = instance.getPoolInfo(poolNftId);

        // // obtain remaining return values
        // collateralAmount = calculateRequiredCollateral(poolInfo.collateralizationLevel, policyInfo.sumInsuredAmount);
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
        // FIXME: this
        // instance.collateralizePolicy(bundleNftId, policyNftId, collateralAmount);
        return bundleInfo;
    }

    function _underwriteByPool(
        ITreasury.TreasuryInfo memory treasuryInfo,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        bytes memory bundleFilter,
        uint256 collateralAmount
    )
        internal
    {
        address poolAddress = getRegistry().getObjectInfo(treasuryInfo.poolNftId).objectAddress;
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

        // check match between policy and calling product
        NftId productNftId = productInfo.nftId;
        // FIXME: this
        // IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        // require(policyInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");
        // require(instance.getState(policyNftId.toKey32(POLICY())) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");

        // ITreasury.TreasuryInfo memory treasuryInfo;
        // NftId bundleNftId;
        // IBundle.BundleInfo memory bundleInfo;
        // uint256 collateralAmount;

        // (
        //     treasuryInfo,
        //     bundleNftId,
        //     bundleInfo,
        //     collateralAmount
        // ) = _getAndVerifyUnderwritingSetup(
        //     instance,
        //     policyInfo
        // );

        // // lock bundle collateral
        // bundleInfo = _lockCollateralInBundle(
        //     instance,
        //     bundleNftId,
        //     bundleInfo,
        //     policyNftId, 
        //     collateralAmount);

        // // set policy state to underwritten
        // instance.updatePolicyState(policyNftId, UNDERWRITTEN());

        // // optional activation of policy
        // if(activateAt > zeroTimestamp()) {
        //     policyInfo.activatedAt = activateAt;
        //     policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        //     instance.updatePolicyState(policyNftId, ACTIVE());
        // }

        // // optional collection of premium
        // if(requirePremiumPayment) {
        //     uint256 netPremiumAmount = _processPremiumByTreasury(
        //         instance, 
        //         productInfo.nftId,
        //         treasuryInfo, 
        //         policyNftId, 
        //         policyInfo.premiumAmount);

        //     policyInfo.premiumPaidAmount += policyInfo.premiumAmount;
        //     bundleInfo.balanceAmount += netPremiumAmount;
        // }

        // instance.setPolicyInfo(policyNftId, policyInfo);
        // instance.setBundleInfo(bundleNftId, bundleInfo);

        // // involve pool if necessary
        // {
        //     NftId poolNftId = treasuryInfo.poolNftId;
        //     ISetup.PoolSetupInfo memory poolInfo = instance.getPoolInfo(poolNftId);

        //     if(poolInfo.isVerifying) {
        //         _underwriteByPool(
        //             treasuryInfo,
        //             policyNftId,
        //             policyInfo,
        //             bundleInfo.filter,
        //             collateralAmount
        //         );
        //     }
        // }

        // TODO add logging
    }

    function calculateRequiredCollateral(UFixed collateralizationLevel, uint256 sumInsuredAmount) public pure override returns(uint256 collateralAmount) {
        UFixed sumInsuredUFixed = UFixedLib.toUFixed(sumInsuredAmount);
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredUFixed;
        return collateralUFixed.toInt();
    } 

    function collectPremium(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());

        // perform actual token transfers
        // FIXME: this
        // IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        // ITreasury.TreasuryInfo memory treasuryInfo = instance.getTreasuryInfo(productInfo.nftId);

        // uint256 premiumAmount = policyInfo.premiumAmount;
        // _processPremiumByTreasury(instance, productInfo.nftId, treasuryInfo, policyNftId, premiumAmount);

        // // policy level book keeping for premium paid
        // policyInfo.premiumPaidAmount += premiumAmount;

        // // optional activation of policy
        // if(activateAt > zeroTimestamp()) {
        //     require(
        //         policyInfo.activatedAt.eqz(),
        //         "ERROR:PRS-030:ALREADY_ACTIVATED");

        //     policyInfo.activatedAt = activateAt;
        //     policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        //     instance.updatePolicyState(policyNftId, ACTIVE());
        // }

        // instance.setPolicyInfo(policyNftId, policyInfo);

        // TODO add logging
    }

    // FIXME: this
    function activate(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());

        // IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);

        // require(
        //     policyInfo.activatedAt.eqz(),
        //     "ERROR:PRS-020:ALREADY_ACTIVATED");

        // policyInfo.activatedAt = activateAt;
        // policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        // instance.setPolicyInfo(policyNftId, policyInfo);
        // instance.updatePolicyState(policyNftId, ACTIVE());

        // TODO add logging
    }

    function close(
        NftId policyNftId
    ) external override // solhint-disable-next-line no-empty-blocks
    {

    }

    function _getPoolNftId(
        IInstance instance,
        NftId productNftId
    )
        internal
        view
        returns (NftId poolNftid)
    {
        // FIXME: this
        // return instance.getTreasuryInfo(productNftId).poolNftId;
    }


    function _processPremiumByTreasury(
        IInstance instance,
        NftId productNftId,
        ITreasury.TreasuryInfo memory treasuryInfo,
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
        returns (uint256 netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumAmount > 0) {
            // FIXME: this
            // TokenHandler tokenHandler = instance.getTokenHandler(productNftId);
            // address policyOwner = getRegistry().ownerOf(policyNftId);
            // address poolWallet = instance.getComponentWallet(treasuryInfo.poolNftId);
            // netPremiumAmount = premiumAmount;
            // Fee memory productFee = treasuryInfo.productFee;

            // if (FeeLib.feeIsZero(productFee)) {
            //     tokenHandler.transfer(
            //         policyOwner,
            //         poolWallet,
            //         premiumAmount
            //     );
            // } else {
            //     (uint256 feeAmount, uint256 netAmount) = instance.calculateFeeAmount(
            //         premiumAmount,
            //         productFee
            //     );

            //     address productWallet = instance.getComponentWallet(productNftId);
            //     tokenHandler.transfer(policyOwner, productWallet, feeAmount);
            //     tokenHandler.transfer(policyOwner, poolWallet, netAmount);
            //     netPremiumAmount = netAmount;
            // }
        }

        // TODO add logging
    }
}
