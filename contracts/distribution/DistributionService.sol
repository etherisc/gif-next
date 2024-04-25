// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceAccessManager} from "../instance/InstanceAccessManager.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {PRODUCT_SERVICE_ROLE, DISTRIBUTION_OWNER_ROLE} from "../type/RoleId.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, DISTRIBUTION, DISTRIBUTOR, REGISTRY} from "../type/ObjectType.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {RoleId} from "../type/RoleId.sol";

import {IVersionable} from "../shared/IVersionable.sol";
import {Versionable} from "../shared/Versionable.sol";

import {IService} from "../shared/IService.sol";
import {Service} from "../shared/Service.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IDistributionComponent} from "../distribution/IDistributionComponent.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IPricingService} from "../product/IPricingService.sol";

import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {DistributorType, DistributorTypeLib} from "../type/DistributorType.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../type/Referral.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {Key32} from "../type/Key32.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";


contract DistributionService is
    ComponentVerifyingService,
    IDistributionService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;
    using UFixedLib for UFixed;
    using FeeLib for Fee;
    using ReferralLib for ReferralId;

    IInstanceService private _instanceService;
    IRegistryService private _registryService;
    
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        address initialOwner;
        address registryAddress;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));
        // TODO while DistributionService is not deployed in DistributionServiceManager constructor
        //      owner is DistributionServiceManager deployer
        initializeService(registryAddress, address(0), owner);

        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        registerInterface(type(IDistributionService).interfaceId);
    }

    function getDomain() public pure override returns(ObjectType) {
        return DISTRIBUTION();
    }

    // TODO cleanup
    // function register(address distributionAddress) 
    //     external
    //     returns(NftId distributionNftId)
    // {
    //     (
    //         IComponent component,
    //         address owner,
    //         IInstance instance,
    //         NftId instanceNftId
    //     ) = _checkComponentForRegistration(
    //         distributionAddress,
    //         DISTRIBUTION(),
    //         DISTRIBUTION_OWNER_ROLE());

    //     IRegistry.ObjectInfo memory distributionInfo = _registryService.registerDistribution(component, owner);
    //     IDistributionComponent distribution = IDistributionComponent(distributionAddress);
    //     distribution.linkToRegisteredNftId();
    //     distributionNftId = distributionInfo.nftId;

    //     instance.getInstanceStore().createDistributionSetup(distributionNftId, distribution.getSetupInfo());
    //     // TODO move to distribution?
    //     bytes4[][] memory selectors = new bytes4[][](2);
    //     selectors[0] = new bytes4[](1);
    //     // TODO check if array size should be 1 instead of 2
    //     selectors[1] = new bytes4[](2);

    //     selectors[0][0] = IDistributionComponent.setFees.selector;
    //     selectors[1][0] = IDistributionComponent.processRenewal.selector;

    //     RoleId[] memory roles = new RoleId[](2);
    //     roles[0] = DISTRIBUTION_OWNER_ROLE();
    //     roles[1] = PRODUCT_SERVICE_ROLE();

    //     _instanceService.createGifTarget(
    //         instanceNftId, 
    //         distributionAddress, 
    //         distribution.getName(), 
    //         selectors, 
    //         roles);
    // }

    // function setFees(
    //     Fee memory minDistributionOwnerFee,
    //     Fee memory distributionFee
    // )
    //     external
    //     override
    // {
    //     if (minDistributionOwnerFee.fractionalFee > distributionFee.fractionalFee) {
    //         revert ErrorIDistributionServiceMinFeeTooHigh(minDistributionOwnerFee.fractionalFee.toInt(), distributionFee.fractionalFee.toInt());
    //     }

    //     (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
    //     InstanceReader instanceReader = instance.getInstanceReader();

    //     ISetup.DistributionSetupInfo memory distSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
    //     distSetupInfo.minDistributionOwnerFee = minDistributionOwnerFee;
    //     distSetupInfo.distributionFee = distributionFee;
        
    //     instance.getInstanceStore().updateDistributionSetup(distributionNftId, distSetupInfo, KEEP_STATE());
    // }

    function createDistributorType(
        string memory name,
        UFixed minDiscountPercentage,
        UFixed maxDiscountPercentage,
        UFixed commissionPercentage,
        uint32 maxReferralCount,
        uint32 maxReferralLifetime,
        bool allowSelfReferrals,
        bool allowRenewals,
        bytes memory data
    )
        external
        returns (DistributorType distributorType)
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();

        {
            NftId productNftId = _getProductNftId(instanceReader, distributionNftId);
            IComponents.ProductInfo memory productInfo = instance.getInstanceReader().getProductInfo(productNftId);
            UFixed variableFeesPartsTotal = productInfo.minDistributionOwnerFee.fractionalFee.add(commissionPercentage);
            UFixed maxDiscountPercentageLimit = productInfo.distributionFee.fractionalFee.sub(variableFeesPartsTotal);
            if (maxDiscountPercentage.gt(maxDiscountPercentageLimit)) {
                revert ErrorIDistributionServiceMaxDiscountTooHigh(maxDiscountPercentage.toInt(), maxDiscountPercentageLimit.toInt());
            }
        }

        distributorType = DistributorTypeLib.toDistributorType(distributionNftId, name);
        IDistribution.DistributorTypeInfo memory info = IDistribution.DistributorTypeInfo(
            name,
            minDiscountPercentage,
            maxDiscountPercentage,
            commissionPercentage,
            maxReferralCount,
            maxReferralLifetime,
            allowSelfReferrals,
            allowRenewals,
            data);

        instance.getInstanceStore().createDistributorType(distributorType, info);
    }


    function createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    )
        external 
        virtual
        returns (NftId distributorNftId)
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());

        distributorNftId = _registryService.registerDistributor(
            IRegistry.ObjectInfo(
                NftIdLib.zero(), 
                distributionNftId,
                DISTRIBUTOR(),
                true, // intercepting property for bundles is defined on pool
                address(0),
                distributor,
                ""
            ));

        IDistribution.DistributorInfo memory info = IDistribution.DistributorInfo(
            distributorType,
            true, // active
            data,
            AmountLib.zero(),
            0);

        instance.getInstanceStore().createDistributor(distributorNftId, info);
    }

    // function updateDistributorType(
    //     NftId distributorNftId,
    //     DistributorType distributorType,
    //     bytes memory data
    // )
    //     external
    //     virtual
    // {
    //     (, IInstance instance) = _getAndVerifyCallingDistribution();
    //     InstanceReader instanceReader = instance.getInstanceReader();
    //     IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
    //     distributorInfo.distributorType = distributorType;
    //     distributorInfo.data = data;
    //     instance.updateDistributor(distributorNftId, distributorInfo, KEEP_STATE());
    // }


    function createReferral(
        NftId distributorNftId,
        string memory code,
        UFixed discountPercentage,
        uint32 maxReferrals,
        Timestamp expiryAt,
        bytes memory data
    )
        external
        virtual
        returns (ReferralId referralId)
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());

        if (bytes(code).length == 0) {
            revert ErrorIDistributionServiceInvalidReferral(code);
        }
        if (expiryAt.eqz()) {
            revert ErrorIDistributionServiceExpirationInvalid(expiryAt);
        }

        InstanceReader instanceReader = instance.getInstanceReader();
        DistributorType distributorType = instanceReader.getDistributorInfo(distributorNftId).distributorType;
        IDistribution.DistributorTypeInfo memory distributorTypeData = instanceReader.getDistributorTypeInfo(distributorType);

        if (distributorTypeData.maxReferralCount < maxReferrals) {
            revert ErrorIDistributionServiceMaxReferralsExceeded(distributorTypeData.maxReferralCount);
        }
        if (distributorTypeData.minDiscountPercentage > discountPercentage) {
            revert ErrorIDistributionServiceDiscountTooLow(distributorTypeData.minDiscountPercentage.toInt(), discountPercentage.toInt());
        }
        if (distributorTypeData.maxDiscountPercentage < discountPercentage) {
            revert ErrorIDistributionServiceDiscountTooHigh(distributorTypeData.maxDiscountPercentage.toInt(), discountPercentage.toInt());
        }
        if (expiryAt.toInt() - TimestampLib.blockTimestamp().toInt() > distributorTypeData.maxReferralLifetime) {
            revert ErrorIDistributionServiceExpiryTooLong(distributorTypeData.maxReferralLifetime, expiryAt.toInt());
        }

        referralId = ReferralLib.toReferralId(distributionNftId, code);
        IDistribution.ReferralInfo memory info = IDistribution.ReferralInfo(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            0, // used referrals
            expiryAt,
            data
        );

        instance.getInstanceStore().createReferral(referralId, info);
        return referralId;
    }

    function processSale(
        NftId distributionNftId, // assume always of distribution type
        ReferralId referralId,
        IPolicy.Premium memory premium
    )
        external
        virtual
    {
        bool isReferral = ! referralId.eqz();
        bool referralValid = referralIsValid(distributionNftId, referralId);

        if (isReferral && ! referralValid) {
            revert ErrorIDistributionServiceReferralInvalid(distributionNftId, referralId);
        }

        IInstance instance = _getInstanceForDistribution(distributionNftId);
        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();
        IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);
        IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
        
        Amount distributionOwnerFee = AmountLib.toAmount(premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount);
        Amount commissionAmount = AmountLib.toAmount(premium.commissionAmount);

        // TODO fix/refactor to new setup
        // ISetup.DistributionSetupInfo memory setupInfo = reader.getDistributionSetupInfo(distributionNftId);
        // if (distributionOwnerFee.gtz()) {
        //     setupInfo.sumDistributionOwnerFees += distributionOwnerFee.toInt();
        //     store.updateDistributionSetup(distributionNftId, setupInfo, KEEP_STATE());
        // }

        if (isReferral && referralValid) {
            referralInfo.usedReferrals += 1;
            store.updateReferral(referralId, referralInfo, KEEP_STATE());

            if (commissionAmount.gtz()) {
                distributorInfo.commissionAmount = distributorInfo.commissionAmount + commissionAmount;
                distributorInfo.numPoliciesSold += 1;
                store.updateDistributor(referralInfo.distributorNftId, distributorInfo, KEEP_STATE());
            }
        }
    }

    // TODO: zero should return false
    function referralIsValid(NftId distributionNftId, ReferralId referralId) public view returns (bool isValid) {
        IInstance instance = _getInstanceForDistribution(distributionNftId);
        IDistribution.ReferralInfo memory info = instance.getInstanceReader().getReferralInfo(referralId);

        if (info.distributorNftId.eqz()) {
            return false;
        }

        isValid = info.expiryAt.eqz() || (info.expiryAt.gtz() && TimestampLib.blockTimestamp() <= info.expiryAt);
        isValid = isValid && info.usedReferrals < info.maxReferrals;
    }

    function _getInstanceForDistribution(NftId distributionNftId)
        internal
        view
        returns(IInstance instance)
    {
        NftId instanceNftId = getRegistry().getObjectInfo(distributionNftId).parentNftId;
        address instanceAddress = getRegistry().getObjectInfo(instanceNftId).objectAddress;
        return IInstance(instanceAddress);
    }

}