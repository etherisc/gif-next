// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {AmountLib} from "../../types/Amount.sol";
import {Seconds} from "../../types/Seconds.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, BUNDLE, PRICE} from "../../types/ObjectType.sol";
import {APPLIED, REVOKED, ACTIVE, KEEP_STATE} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {AmountLib} from "../../types/Amount.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";

import {IRegistry} from "../../registry/IRegistry.sol";

import {IProductComponent} from "../../components/IProductComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {Product} from "../../components/Product.sol";

import {IComponents} from "../module/IComponents.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury} from "../module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";

import {ComponentService} from "../base/ComponentService.sol";

import {IInstance} from "../IInstance.sol";
import {InstanceReader} from "../InstanceReader.sol";

import {IApplicationService} from "./IApplicationService.sol";
import {IBundleService} from "./IBundleService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IPoolService} from "./IPoolService.sol";
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
            premiumAmount:      premium.premiumAmount,
            premiumPaidAmount:  0,
            lifetime:           lifetime,
            applicationData:    applicationData,
            policyData:         "",
            claimsCount:        0,
            openClaimsCount:    0,
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
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(PRODUCT());
        instance.getInstanceStore().updateApplicationState(applicationNftId, REVOKED());
    }

    // internal functions
}