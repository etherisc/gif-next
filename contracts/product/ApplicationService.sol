// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AmountLib} from "../type/Amount.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Blocknumber, blockNumber} from "../type/Blocknumber.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, BUNDLE, PRICE} from "../type/ObjectType.sol";
import {APPLIED, REVOKED, ACTIVE, KEEP_STATE} from "../type/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../type/NftId.sol";
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
import {ISetup} from "../instance/module/ISetup.sol";

import {ComponentService} from "../shared/ComponentService.sol";

import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "../pool/IBundleService.sol";
import {IDistributionService} from "../distribution/IDistributionService.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IPricingService} from "./IPricingService.sol";


contract ApplicationService is 
    ComponentService, 
    IApplicationService
{
    IDistributionService internal _distributionService;
    IPricingService internal _pricingService;

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

        initializeService(registryAddress, address(0), owner);
        registerInterface(type(IApplicationService).interfaceId);

        _distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION()));
        _pricingService = IPricingService(_getServiceAddress(PRICE()));
    }


    function getDomain() public pure override returns(ObjectType) {
        return APPLICATION();
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
        (NftId productNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        // TODO: add validations (see create bundle in pool service)

        applicationNftId = getRegistryService().registerPolicy(
            IRegistry.ObjectInfo(
                zeroNftId(),
                productNftId,
                POLICY(),
                false, // intercepting property for policies is defined on product
                address(0),
                applicationOwner,
                ""
            )
        );

        // (uint256 premiumAmount,,,,,) = calculatePremium(
        IPolicy.Premium memory premium = _pricingService.calculatePremium(
            productNftId,
            riskId,
            sumInsuredAmount,
            lifetime,
            applicationData,
            bundleNftId,
            referralId
        );

        IPolicy.PolicyInfo memory policyInfo = IPolicy.PolicyInfo({
            productNftId:       productNftId,
            bundleNftId:        bundleNftId,
            referralId:         referralId,
            riskId:             riskId,
            sumInsuredAmount:   sumInsuredAmount,
            premiumAmount:      AmountLib.toAmount(premium.premiumAmount),
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
        
        instance.getInstanceStore().createApplication(applicationNftId, policyInfo);

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
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        instance.getInstanceStore().updateApplicationState(applicationNftId, REVOKED());
    }

    // internal functions
}