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
import {Seconds} from "../type/Seconds.sol";
import {zeroTimestamp} from "../type/Timestamp.sol";
import {ObjectType, DISTRIBUTION, PRODUCT, REGISTRY, APPLICATION, POLICY, PRICE} from "../type/ObjectType.sol";
import {REVOKED} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Amount, AmountLib} from "../type/Amount.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";



contract ApplicationService is 
    ComponentVerifyingService, 
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
        initializer()
    {
        (
            address registryAddress,
            address authority
        ) = abi.decode(data, (address, address));

        _initializeService(registryAddress, authority, owner);

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));
        _pricingService = IPricingService(_getServiceAddress(PRICE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        _registerInterface(type(IApplicationService).interfaceId);
    }


    function _checkLinkedpplicationParameters(
        InstanceReader instanceReader,
        NftId productNftId,
        RiskId rirskId,
        ReferralId referralId,
        NftId bundleNftId
    )
        internal
        virtual
        view
    {
        IComponents.ProductInfo memory productInfo = instanceReader.getProductInfo(productNftId);

        // TODO check riskId with product

        // TODO check referral with distribution

        // check bundle with pool
        NftId productPoolNftId = productInfo.poolNftId;
        NftId bundlePoolNftId = instanceReader.getBundleInfo(bundleNftId).poolNftId;
        if(bundlePoolNftId != productPoolNftId) {
            revert ErrorApplicationServiceBundlePoolMismatch(bundleNftId, productPoolNftId, bundlePoolNftId);
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
            false, // intercepting property for policies is defined on product
            address(0),
            applicationOwner,
            "");

        applicationNftId = _registryService.registerPolicy(objectInfo);
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
        nonReentrant()
        returns (NftId applicationNftId)
    {
        (NftId productNftId,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());

        // check if provided references are valid and linked to calling product contract
        InstanceReader instanceReader = instance.getInstanceReader();
        _checkLinkedpplicationParameters(
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
        instance.getInstanceStore().createApplication(
            applicationNftId, 
            applicationInfo);

        // TODO: add logging
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
        nonReentrant()
        returns (NftId applicationNftId)
    {
        // TODO implement
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
        nonReentrant()
    {
        // TODO implement
    }

    function revoke(NftId applicationNftId)
        external
        virtual
        nonReentrant()
    {
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        instance.getInstanceStore().updateApplicationState(applicationNftId, REVOKED());
    }

    // internal functions


    function _getDomain() internal pure override returns(ObjectType) {
        return APPLICATION();
    }
}