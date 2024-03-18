// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "./IApplicationService.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {Product} from "../../components/Product.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IComponents} from "../module/IComponents.sol";
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
import {ObjectType, DISTRIBUTION, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, BUNDLE} from "../../types/ObjectType.sol";
import {APPLIED, REVOKED, UNDERWRITTEN, ACTIVE, KEEP_STATE, CLOSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {ComponentService} from "../base/ComponentService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";


contract ApplicationService is 
    ComponentService, 
    IApplicationService
{
    IDistributionService internal _distributionService;

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

        initializeService(registryAddress, owner);
        registerInterface(type(IApplicationService).interfaceId);

        _distributionService = IDistributionService(getRegistry().getServiceAddress(DISTRIBUTION(), getMajorVersion()));
    }


    function getDomain() public pure override(IService, Service) returns(ObjectType) {
        return APPLICATION();
    }


    function create(
        address applicationOwner,
        RiskId riskId,
        uint256 sumInsuredAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        external
        virtual
        returns (NftId applicationNftId)
    {
        (IRegistry.ObjectInfo memory productInfo, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        // TODO: add validations (see create bundle in pool service)

        applicationNftId = getRegistryService().registerPolicy(
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

        // (uint256 premiumAmount,,,,,) = calculatePremium(
        IPolicy.Premium memory premium = calculatePremium(
            productInfo.nftId,
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
            premium.premiumAmount,
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
        
        instance.createApplication(applicationNftId, policyInfo);

        // TODO: add logging
    }


    function renew(
        NftId policyNftId, // policy to be renewd (renewal inherits policy attributes)
        NftId bundleNftId // will likely need a newer bundle for underwriting
    )
        external
        virtual override
        returns (NftId applicationNftId)
    {

    }


    function adjust(
        NftId applicationNftId,
        RiskId riskId,
        NftId bundleNftId,
        ReferralId referralId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
        bytes memory applicationData
    )
        external
        virtual override
    {

    }

    function revoke(NftId applicationNftId)
        external
        virtual override
    {
        (, IInstance instance) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        instance.updateApplicationState(applicationNftId, REVOKED());
    }

    // TODO: maybe move this to a pricing service later
    function calculatePremium(
        NftId productNftId,
        RiskId riskId,
        uint256 sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        public
        view
        virtual override
        returns (
            IPolicy.Premium memory premium
        )
    {
        uint256 netPremiumAmount = _getAndVerifyProduct(productNftId).calculateNetPremium(
            sumInsuredAmount,
            riskId,
            lifetime,
            applicationData
        );

        premium = _getFixedFeeAmounts(
            netPremiumAmount,
            _getAndVerifyProduct(productNftId),
            bundleNftId,
            referralId
        );

        (
            premium
        ) = _calculateVariableFeeAmounts(
            premium,
            _getAndVerifyProduct(productNftId),
            bundleNftId,
            referralId
        );
    }


    // internal functions
    function _getFixedFeeAmounts(
        uint256 netPremiumAmount,
        Product product,
        NftId bundleNftId,
        ReferralId referralId
    )
        internal
        view
        returns (
            IPolicy.Premium memory premium
        )
    {
        InstanceReader instanceReader;
        {
            IInstance instance = product.getInstance();
            instanceReader = instance.getInstanceReader();
        }
        
        NftId poolNftId = product.getPoolNftId();
        premium = IPolicy.Premium(
            netPremiumAmount, // net premium
            netPremiumAmount, // full premium
            0, // premium
            0, 0, 0, 0, // fix fees
            0, 0, 0, 0, // variable fees
            0, 0, 0, 0); // distribution owner fee/commission/discount

        {
            {
                ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(product.getProductNftId());
                uint256 t = productSetupInfo.productFee.fixedFee;
                premium.productFeeFixAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                bytes memory componentData = instanceReader.getComponentInfo(poolNftId).data;
                uint256 t = abi.decode(componentData, (IComponents.PoolInfo)).poolFee.fixedFee;
                premium.poolFeeFixAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
                if(bundleInfo.poolNftId != poolNftId) {
                    revert IApplicationServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, poolNftId);
                }
                uint256 t = bundleInfo.fee.fixedFee;
                premium.bundleFeeFixAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                ISetup.DistributionSetupInfo memory distInto = instanceReader.getDistributionSetupInfo(product.getDistributionNftId());
                uint256 t = distInto.distributionFee.fixedFee;
                premium.distributionFeeFixAmount = t;
                premium.fullPremiumAmount += t;
            }
        }
        
    }

    function _calculateVariableFeeAmounts(
        IPolicy.Premium memory premium,
        Product product,
        NftId bundleNftId,
        ReferralId referralId
    )
        internal
        view
        returns (
            IPolicy.Premium memory finalPremium
        )
    {
        InstanceReader instanceReader;
        {
            IInstance instance = product.getInstance();
            instanceReader = instance.getInstanceReader();
        }
        
        NftId poolNftId = product.getPoolNftId();
        uint256 netPremiumAmount = premium.netPremiumAmount;

        {
            {
                ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(product.getProductNftId());
                uint256 t = (UFixedLib.toUFixed(netPremiumAmount) * productSetupInfo.productFee.fractionalFee).toInt();
                premium.productFeeVarAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                bytes memory componentData = instanceReader.getComponentInfo(poolNftId).data;
                UFixed poolFractionalFee = abi.decode(componentData, (IComponents.PoolInfo)).poolFee.fractionalFee;
                uint256 t = (UFixedLib.toUFixed(netPremiumAmount) * poolFractionalFee).toInt();
                premium.poolFeeVarAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
                if(bundleInfo.poolNftId != poolNftId) {
                    revert IApplicationServiceBundlePoolMismatch(bundleNftId, bundleInfo.poolNftId, poolNftId);
                }
                uint256 t = (UFixedLib.toUFixed(netPremiumAmount) * bundleInfo.fee.fractionalFee).toInt();
                premium.bundleFeeVarAmount = t;
                premium.fullPremiumAmount += t;
            }
            {
                premium = _distributionService.calculateFeeAmount(
                    product.getDistributionNftId(),
                    referralId,
                    premium
                );
            }
        }

        return premium;
    }


    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }

    function _getAndVerifyProduct(NftId productNftId) internal view returns (Product product) {
        IRegistry registry = getRegistry();        
        IRegistry.ObjectInfo memory productInfo = registry.getObjectInfo(productNftId);
        require(productInfo.objectType == PRODUCT(), "OBJECT_TYPE_INVALID");
        product = Product(productInfo.objectAddress);
    }
}
