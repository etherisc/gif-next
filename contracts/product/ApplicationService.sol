// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IApplicationService} from "./IApplicationService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";

import {AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {Seconds} from "../type/Seconds.sol";
import {zeroTimestamp} from "../type/Timestamp.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, PRODUCT, REGISTRY, APPLICATION, POLICY, PRICE} from "../type/ObjectType.sol";
import {REVOKED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Amount, AmountLib} from "../type/Amount.sol";
import {Service} from "../shared/Service.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";


contract ApplicationService is 
    Service, 
    IApplicationService
{
    IDistributionService private _distributionService;
    IPricingService private _pricingService;
    IRegistryService private _registryService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing()
    {
        (
            address authority
        ) = abi.decode(data, (address));

        __Service_init(authority, owner);

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));
        _pricingService = IPricingService(_getServiceAddress(PRICE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        _registerInterface(type(IApplicationService).interfaceId);
    }

    // TODO product - bundle - risk - refferal - distribution
    // checkBundle() is faster then checking with registry but first need to know poolNftId
    // check pool, get its nftIdf and instance -> instacne.getBundleSet.checkBundle(bundsleNftId) ???? 
    function _checkLinkedApplicationParameters(
        InstanceReader instanceReader,
        NftId productNftId,
        RiskId riskId,
        ReferralId referralId,
        NftId bundleNftId
    )
        internal
        virtual
        view
    {
        // check risk with product
        (bool exists, bool active) = instanceReader.getRiskSet().checkRisk(productNftId, riskId);
        if (!exists) { revert ErrorApplicationServiceRiskUnknown(riskId, productNftId); }
        if (!active) { revert ErrorApplicationServiceRiskLocked(riskId, productNftId); }

        NftId riskProductNftId = instanceReader.getRiskInfo(riskId).productNftId;
        if (productNftId != riskProductNftId) {
            revert ErrorApplicationServiceRiskProductMismatch(riskId, riskProductNftId, productNftId);
        }

        // check bundle with pool
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);
        {
            NftId poolNftId = productInfo.poolNftId;
            (exists, active) = instanceReader.getBundleSet().checkBundle(poolNftId, bundleNftId);
            if (!exists) { revert ErrorApplicationServiceBundleUnknown(bundleNftId, poolNftId); }
            if (!active) { revert ErrorApplicationServiceBundleLocked(bundleNftId, poolNftId); }
        }

        // check referral with distribution
        {
            if (productInfo.hasDistribution && ! referralId.eqz()) {
                if (!_distributionService.referralIsValid(productInfo.distributionNftId, referralId)) {
                    revert ErrorApplicationServiceReferralInvalid(productNftId, productInfo.distributionNftId, referralId);
                }
            }
        }
    }


    function _registerApplication(
        NftId productNftId,
        address applicationOwner
    )
        internal
        virtual
        returns (NftId applicationNftId)
    {
        IRegistry.ObjectInfo memory objectInfo = IRegistry.ObjectInfo(
            NftIdLib.zero(),
            productNftId,
            POLICY(),
            getRelease(),
            false, // intercepting property for policies is defined on product
            address(0));

        applicationNftId = _registryService.registerPolicy(objectInfo, applicationOwner, "");
    }


    function _calculatePremiumAmount(
        IPolicy.PolicyInfo memory info
    )
        internal
        virtual
        view
        returns (Amount premiumAmount)
    {
        return _pricingService.calculatePremium(
                info.productNftId,
                info.riskId,
                info.sumInsuredAmount,
                info.lifetime,
                info.applicationData,
                info.bundleNftId,
                info.referralId
            ).premiumAmount;
    }


    function create(
        address applicationOwner,
        RiskId riskId,
        Amount sumInsuredAmount,
        Amount premiumAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        external
        virtual
        restricted()
        nonReentrant()
        returns (NftId applicationNftId)
    {
        _checkNftType(bundleNftId, BUNDLE());

        (NftId productNftId, IInstance instance) = ContractLib.getAndVerifyProduct(getRelease());

        // check if provided references are valid and linked to calling product contract
        InstanceReader instanceReader = instance.getInstanceReader();
        _checkLinkedApplicationParameters(
            instanceReader,
            productNftId,
            riskId,
            referralId,
            bundleNftId);

        // register application with registry
        applicationNftId = _registerApplication(productNftId, applicationOwner);

        // create policy info for application
        IPolicy.PolicyInfo memory applicationInfo = _createApplicationInfo(
            productNftId,
            riskId,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            bundleNftId,
            referralId,
            applicationData);

        // register application with instance
        instance.getProductStore().createApplication(
            applicationNftId, 
            applicationInfo);

        _emitApplicationCreatedEvent(applicationNftId, applicationOwner, applicationInfo);
    }

    function _emitApplicationCreatedEvent(
        NftId applicationNftId,
        address applicationOwner,
        IPolicy.PolicyInfo memory applicationInfo
    )
        internal
        virtual
    {
        emit LogApplicationServiceApplicationCreated(
            applicationNftId,
            applicationInfo.productNftId,
            applicationInfo.bundleNftId, 
            applicationInfo.riskId,
            applicationInfo.referralId,
            applicationOwner,
            applicationInfo.sumInsuredAmount,
            applicationInfo.premiumAmount,
            applicationInfo.lifetime
        );
    }

    function _createApplicationInfo(
        NftId productNftId,
        RiskId riskId,
        Amount sumInsuredAmount,
        Amount premiumAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        internal
        virtual
        returns (IPolicy.PolicyInfo memory applicationInfo)
    {
        return IPolicy.PolicyInfo({
            productNftId:       productNftId,
            bundleNftId:        bundleNftId,
            referralId:         referralId,
            riskId:             riskId,
            sumInsuredAmount:   sumInsuredAmount,
            premiumAmount:      premiumAmount,
            lifetime:           lifetime,
            applicationData:    applicationData,
            processData:        "",
            claimsCount:        0,
            openClaimsCount:    0,
            claimAmount:        AmountLib.zero(),
            payoutAmount:       AmountLib.zero(),
            activatedAt:        zeroTimestamp(),
            expiredAt:          zeroTimestamp(),
            closedAt:           zeroTimestamp()
        });
    }

    function renew(
        NftId policyNftId, // policy to be renewd (renewal inherits policy attributes)
        NftId bundleNftId // will likely need a newer bundle for underwriting
    )
        external
        virtual
        restricted()
        nonReentrant()
        returns (NftId applicationNftId)
    {
        _checkNftType(policyNftId, POLICY());
        _checkNftType(bundleNftId, BUNDLE());
        
        // TODO: implement

        emit LogApplicationServiceApplicationRenewed(policyNftId, bundleNftId);
    }


    function adjust(
        NftId applicationNftId,
        RiskId riskId,
        NftId bundleNftId,
        ReferralId referralId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData
    )
        external
        virtual
        restricted()
        nonReentrant()
    {
        _checkNftType(applicationNftId, POLICY());
        _checkNftType(bundleNftId, BUNDLE());

        // TODO: implement
        
        emit LogApplicationServiceApplicationAdjusted(applicationNftId, bundleNftId, riskId, referralId, sumInsuredAmount, lifetime);
    }

    function revoke(NftId applicationNftId)
        external
        virtual
        restricted()
        nonReentrant()
    {
        (, IInstance instance) = ContractLib.getAndVerifyProductForPolicy(
            applicationNftId, getRelease());

        instance.getProductStore().updateApplicationState(applicationNftId, REVOKED());
        emit LogApplicationServiceApplicationRevoked(applicationNftId);
    }

    // internal functions


    function _getDomain() internal pure override returns(ObjectType) {
        return APPLICATION();
    }
}