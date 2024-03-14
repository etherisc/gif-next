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
        uint256 lifetime,
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
        instance.updateApplicationState(applicationNftId, APPLIED());

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
    // FIXME: this !!
    function calculatePremium(
        NftId productNftId,
        RiskId riskId,
        uint256 sumInsuredAmount,
        uint256 lifetime,
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

        (
            premium
        ) = _calculateFeeAmounts(
            netPremiumAmount,
            _getAndVerifyProduct(productNftId),
            bundleNftId,
            referralId
        );
    }


    // internal functions
    function _calculateFeeAmounts(
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
            netPremiumAmount,
            netPremiumAmount,
            0, 0, 0, 0, 0);

        {
            {
                ISetup.ProductSetupInfo memory productSetupInfo = instanceReader.getProductSetupInfo(product.getProductNftId());
                (uint256 t,) = FeeLib.calculateFee(productSetupInfo.productFee, netPremiumAmount);
                premium.productFeeAmount = t;
                premium.premiumAmount += t;
            }
            {
                ISetup.PoolSetupInfo memory poolSetupInfo = instanceReader.getPoolSetupInfo(poolNftId);
                (uint256 t,) = FeeLib.calculateFee(poolSetupInfo.poolFee, netPremiumAmount);
                premium.poolFeeAmount = t;
                premium.premiumAmount += t;
            }
            {
                IBundle.BundleInfo memory bundleInfo = instanceReader.getBundleInfo(bundleNftId);
                require(bundleInfo.poolNftId == poolNftId,"ERROR:PRS-035:BUNDLE_POOL_MISMATCH");
                (uint256 t,) = FeeLib.calculateFee(bundleInfo.fee, netPremiumAmount);
                premium.bundleFeeAmount = t;
                premium.premiumAmount += t;
            }
            {
                (uint256 t1, uint256 t2) = _distributionService.calculateFeeAmount(
                    product.getDistributionNftId(),
                    referralId,
                    netPremiumAmount
                );
                premium.distributionFeeAmount = t1;
                premium.comissionAmount = t2;
                premium.premiumAmount += t1 + t2;
            }
        }
        
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
