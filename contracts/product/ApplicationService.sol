// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AmountLib} from "../type/Amount.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, PRODUCT, POOL, REGISTRY, APPLICATION, POLICY, BUNDLE, PRICE} from "../type/ObjectType.sol";
import {APPLIED, REVOKED, ACTIVE, KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {Amount, AmountLib} from "../type/Amount.sol";

import {TokenHandler} from "../shared/TokenHandler.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";
import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {IProductComponent} from "./IProductComponent.sol";
import {IPoolComponent} from "../pool/IPoolComponent.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {Product} from "./Product.sol";

import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRisk} from "../instance/module/IRisk.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury} from "../instance/module/ITreasury.sol";

import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";


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
            address registryAddress,, 
            //address managerAddress
            address authority
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, address(0), owner);

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));
        _pricingService = IPricingService(_getServiceAddress(PRICE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        registerInterface(type(IApplicationService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return APPLICATION();
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
        return AmountLib.toAmount(
            _pricingService.calculatePremium(
                info.productNftId,
                info.riskId,
                info.sumInsuredAmount,
                info.lifetime,
                info.applicationData,
                info.bundleNftId,
                info.referralId
            ).premiumAmount);
    }


    function create(
        address applicationOwner,
        RiskId riskId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        NftId bundleNftId,
        ReferralId referralId,
        bytes memory applicationData
    )
        external
        virtual
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
        IPolicy.PolicyInfo memory applicationInfo = IPolicy.PolicyInfo({
            productNftId:       productNftId,
            bundleNftId:        bundleNftId,
            referralId:         referralId,
            riskId:             riskId,
            sumInsuredAmount:   sumInsuredAmount,
            premiumAmount:      AmountLib.zero(),
            premiumPaidAmount:  AmountLib.zero(),
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

        // calculate premium amount
        applicationInfo.premiumAmount = _calculatePremiumAmount(applicationInfo);

        // register application with instance
        instance.getInstanceStore().createApplication(
            applicationNftId, 
            applicationInfo);

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
        Amount sumInsuredAmount,
        Seconds lifetime,
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
        (,, IInstance instance) = _getAndVerifyActiveComponent(PRODUCT());
        instance.getInstanceStore().updateApplicationState(applicationNftId, REVOKED());
    }

    // internal functions
}