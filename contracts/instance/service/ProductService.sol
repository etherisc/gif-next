// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IPolicy, IPolicyModule} from "../module/policy/IPolicy.sol";
import {IPool} from "../module/pool/IPoolModule.sol";
import {IBundle} from "../module/bundle/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/module/treasury/ITreasury.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {Timestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedMathLib} from "../../types/UFixed.sol";
import {ObjectType, INSTANCE, PRODUCT, POLICY} from "../../types/ObjectType.sol";
import {APPLIED, UNDERWRITTEN, ACTIVE} from "../../types/StateId.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {ComponentServiceBase} from "../base/ComponentServiceBase.sol";
import {IProductService} from "./IProductService.sol";

// TODO or name this ProtectionService to have Product be something more generic (loan, savings account, ...)
contract ProductService is ComponentServiceBase, IProductService {
    using NftIdLib for NftId;

    string public constant NAME = "ProductService";

    event LogProductServiceSender(address sender);

    constructor(
        address registry,
        NftId registryNftId
    ) ComponentServiceBase(registry, registryNftId) // solhint-disable-next-line no-empty-blocks
    {
        _registerInterface(type(IProductService).interfaceId);
    }

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory policyFee,
        Fee memory processingFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        instance.setProductFees(productInfo.nftId, policyFee, processingFee);
    }

    function createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external override returns (NftId policyNftId) {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        NftId productNftId = productInfo.nftId;
        // TODO add validations (see create bundle in pool service)

        policyNftId = this.getRegistry().registerObjectForInstance(
            productNftId,
            POLICY(),
            applicationOwner,
            ""
        );

        instance.createPolicyInfo(
            policyNftId,
            productNftId,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId
        );

        // TODO add logging
    }

    function _getAndVerifyUnderwritingSetup(
        IInstance instance,
        IPolicy.PolicyInfo memory policyInfo
    )
        internal
        view
        returns (
            ITreasury.ProductSetup memory productSetup,
            NftId bundleNftId,
            IBundle.BundleInfo memory bundleInfo,
            uint256 collateralAmount
        )
    {
        // check match between policy and bundle (via pool)
        productSetup = instance.getProductSetup(policyInfo.productNftId);
        bundleNftId = policyInfo.bundleNftId;
        bundleInfo = instance.getBundleInfo(bundleNftId);
        require(bundleInfo.poolNftId == productSetup.poolNftId, "POLICY_BUNDLE_MISMATCH");

        // calculate required collateral
        NftId poolNftId = productSetup.poolNftId;
        IPool.PoolInfo memory poolInfo = instance.getPoolInfo(poolNftId);

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
        instance.collateralizePolicy(bundleNftId, policyNftId, collateralAmount);
        return bundleInfo;
    }

    function _underwriteByPool(
        ITreasury.ProductSetup memory productSetup,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        bytes memory bundleFilter,
        uint256 collateralAmount
    )
        internal
    {
        address poolAddress = _registry.getObjectInfo(productSetup.poolNftId).objectAddress;
        IPoolComponent pool = IPoolComponent(poolAddress);
        pool.underwrite(
            policyNftId, 
            policyInfo.applicationData, 
            bundleFilter,
            collateralAmount);
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
        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        require(policyInfo.productNftId == productNftId, "POLICY_PRODUCT_MISMATCH");
        require(instance.getPolicyState(policyNftId) == APPLIED(), "ERROR:PRS-021:STATE_NOT_APPLIED");

        ITreasury.ProductSetup memory productSetup;
        NftId bundleNftId;
        IBundle.BundleInfo memory bundleInfo;
        uint256 collateralAmount;

        (
            productSetup,
            bundleNftId,
            bundleInfo,
            collateralAmount
        ) = _getAndVerifyUnderwritingSetup(
            instance,
            policyInfo
        );

        // lock bundle collateral
        bundleInfo = _lockCollateralInBundle(
            instance,
            bundleNftId,
            bundleInfo,
            policyNftId, 
            collateralAmount);

        // set policy state to underwritten
        instance.updatePolicyState(policyNftId, UNDERWRITTEN());

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            policyInfo.activatedAt = activateAt;
            policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

            instance.updatePolicyState(policyNftId, ACTIVE());
        }

        // optional collection of premium
        if(requirePremiumPayment) {
            uint256 netPremiumAmount = _processPremiumByTreasury(
                instance, 
                productSetup, 
                policyNftId, 
                policyInfo.premiumAmount);

            policyInfo.premiumPaidAmount += policyInfo.premiumAmount;
            bundleInfo.balanceAmount += netPremiumAmount;
        }

        instance.setPolicyInfo(policyNftId, policyInfo);
        instance.setBundleInfo(bundleNftId, bundleInfo);

        // involve pool if necessary
        {
            NftId poolNftId = productSetup.poolNftId;
            IPool.PoolInfo memory poolInfo = instance.getPoolInfo(poolNftId);

            if(poolInfo.isVerifying) {
                _underwriteByPool(
                    productSetup,
                    policyNftId,
                    policyInfo,
                    bundleInfo.filter,
                    collateralAmount
                );
            }
        }

        // TODO add logging
    }

    function calculateRequiredCollateral(UFixed collateralizationLevel, uint256 sumInsuredAmount) public pure override returns(uint256 collateralAmount) {
        UFixed sumInsuredUFixed = UFixedMathLib.toUFixed(sumInsuredAmount);
        UFixed collateralUFixed =  collateralizationLevel * sumInsuredUFixed;
        return collateralUFixed.toInt();
    } 

    function collectPremium(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());

        // perform actual token transfers
        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);
        ITreasury.ProductSetup memory product = instance.getProductSetup(productInfo.nftId);

        uint256 premiumAmount = policyInfo.premiumAmount;
        _processPremiumByTreasury(instance, product, policyNftId, premiumAmount);

        // policy level book keeping for premium paid
        policyInfo.premiumPaidAmount += premiumAmount;

        // optional activation of policy
        if(activateAt > zeroTimestamp()) {
            require(
                policyInfo.activatedAt.eqz(),
                "ERROR:PRS-030:ALREADY_ACTIVATED");

            policyInfo.activatedAt = activateAt;
            policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

            instance.updatePolicyState(policyNftId, ACTIVE());
        }

        instance.setPolicyInfo(policyNftId, policyInfo);

        // TODO add logging
    }

    function activate(NftId policyNftId, Timestamp activateAt) external override {
        // check caller is registered product
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());

        IPolicy.PolicyInfo memory policyInfo = instance.getPolicyInfo(policyNftId);

        require(
            policyInfo.activatedAt.eqz(),
            "ERROR:PRS-020:ALREADY_ACTIVATED");

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        instance.setPolicyInfo(policyNftId, policyInfo);
        instance.updatePolicyState(policyNftId, ACTIVE());

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
        return instance.getProductSetup(productNftId).poolNftId;
    }

    function _processPremiumByTreasury(
        IInstance instance,
        ITreasury.ProductSetup memory product,
        NftId policyNftId,
        uint256 premiumAmount
    )
        internal
        returns (uint256 netPremiumAmount)
    {
        // process token transfer(s)
        if(premiumAmount > 0) {
            TokenHandler tokenHandler = instance.getTokenHandler(product.productNftId);
            address policyOwner = _registry.getOwner(policyNftId);
            address poolWallet = instance.getPoolSetup(product.poolNftId).wallet;
            netPremiumAmount = premiumAmount;
            Fee memory policyFee = product.policyFee;

            if (FeeLib.feeIsZero(policyFee)) {
                tokenHandler.transfer(
                    policyOwner,
                    poolWallet,
                    premiumAmount
                );
            } else {
                (uint256 feeAmount, uint256 netAmount) = instance.calculateFeeAmount(
                    premiumAmount,
                    policyFee
                );

                tokenHandler.transfer(policyOwner, product.wallet, feeAmount);
                tokenHandler.transfer(policyOwner, poolWallet, netAmount);
                netPremiumAmount = netAmount;
            }
        }

        // TODO add logging
    }
}
