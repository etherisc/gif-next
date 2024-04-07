// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceAccessManager} from "../InstanceAccessManager.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";
import {IPolicy} from "../module/IPolicy.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {PRODUCT_SERVICE_ROLE, DISTRIBUTION_OWNER_ROLE} from "../../types/RoleId.sol";
import {KEEP_STATE} from "../../types/StateId.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, DISTRIBUTION, DISTRIBUTOR, PRICE} from "../../types/ObjectType.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {RoleId} from "../../types/RoleId.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentService} from "../base/ComponentService.sol";
import {InstanceService} from "../InstanceService.sol";
import {IComponent} from "../../components/IComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IPricingService} from "./IPricingService.sol";

import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {DistributorType, DistributorTypeLib} from "../../types/DistributorType.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../../types/Referral.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {Key32} from "../../types/Key32.sol";
import {IDistribution} from "../module/IDistribution.sol";
import {InstanceStore} from "../InstanceStore.sol";


contract DistributionService is
    ComponentService,
    IDistributionService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;
    using UFixedLib for UFixed;
    using FeeLib for Fee;
    using ReferralLib for ReferralId;

    address internal _registryAddress;
    
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
        registerInterface(type(IDistributionService).interfaceId);
    }

    function getDomain() public pure override returns(ObjectType) {
        return DISTRIBUTION();
    }

    function register(address distributionAddress) 
        external
        returns(NftId distributionNftId)
    {
        (
            IComponent component,
            address owner,
            IInstance instance,
            NftId instanceNftId
        ) = _checkComponentForRegistration(
            distributionAddress,
            DISTRIBUTION(),
            DISTRIBUTION_OWNER_ROLE());

        IRegistry.ObjectInfo memory distributionInfo = getRegistryService().registerDistribution(component, owner);
        IDistributionComponent distribution = IDistributionComponent(distributionAddress);
        distribution.linkToRegisteredNftId();
        distributionNftId = distributionInfo.nftId;

        instance.getInstanceStore().createDistributionSetup(distributionNftId, distribution.getSetupInfo());
        // TODO move to distribution?
        bytes4[][] memory selectors = new bytes4[][](2);
        selectors[0] = new bytes4[](1);
        selectors[1] = new bytes4[](2);

        selectors[0][0] = IDistributionComponent.setFees.selector;
        selectors[1][0] = IDistributionComponent.processRenewal.selector;

        RoleId[] memory roles = new RoleId[](2);
        roles[0] = DISTRIBUTION_OWNER_ROLE();
        roles[1] = PRODUCT_SERVICE_ROLE();

        getInstanceService().createGifTarget(
            instanceNftId, 
            distributionAddress, 
            distribution.getName(), 
            selectors, 
            roles);
    }

    function setFees(
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee
    )
        external
        override
    {
        if (minDistributionOwnerFee.fractionalFee > distributionFee.fractionalFee) {
            revert ErrorIDistributionServiceMinFeeTooHigh(minDistributionOwnerFee.fractionalFee.toInt(), distributionFee.fractionalFee.toInt());
        }

        (NftId distributionNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();

        ISetup.DistributionSetupInfo memory distSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        distSetupInfo.minDistributionOwnerFee = minDistributionOwnerFee;
        distSetupInfo.distributionFee = distributionFee;
        
        instance.getInstanceStore().updateDistributionSetup(distributionNftId, distSetupInfo, KEEP_STATE());
    }

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
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(DISTRIBUTION());

        {
            ISetup.DistributionSetupInfo memory setupInfo = instance.getInstanceReader().getDistributionSetupInfo(distributionNftId);
            UFixed variableFeesPartsTotal = setupInfo.minDistributionOwnerFee.fractionalFee.add(commissionPercentage);
            UFixed maxDiscountPercentageLimit = setupInfo.distributionFee.fractionalFee.sub(variableFeesPartsTotal);
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
    ) external returns (NftId distributorNftId)
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(DISTRIBUTION());

        distributorNftId = getRegistryService().registerDistributor(
            IRegistry.ObjectInfo(
                zeroNftId(), 
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
            0,
            0);

        instance.getInstanceStore().createDistributor(distributorNftId, info);
    }

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    ) external virtual
    {
        (,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();
        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        distributorInfo.distributorType = distributorType;
        distributorInfo.data = data;
        instance.getInstanceStore().updateDistributor(distributorNftId, distributorInfo, KEEP_STATE());
    }


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
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyCallingComponentAndInstance(DISTRIBUTION());

        if (bytes(code).length == 0) {
            revert ErrorIDistributionServiceInvalidReferral(code);
        }
        if (expiryAt.eqz()) {
            revert ErrorIDistributionServiceExpirationInvalid(expiryAt);
        }

        InstanceReader instanceReader = instance.getInstanceReader();
        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        DistributorType distributorType = distributorInfo.distributorType;
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
        IPolicy.Premium memory premium,
        uint256 transferredDistributionFeeAmount
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
        ISetup.DistributionSetupInfo memory setupInfo = reader.getDistributionSetupInfo(distributionNftId);
        
        uint256 distributionOwnerFee = premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount;
        uint256 commissionAmount = premium.commissionAmount;

        if (transferredDistributionFeeAmount != distributionOwnerFee + commissionAmount) {
            revert ErrorIDistributionServiceInvalidFeeTransferred(transferredDistributionFeeAmount, distributionOwnerFee + commissionAmount);
        }


        if (distributionOwnerFee > 0) {
            setupInfo.sumDistributionOwnerFees += distributionOwnerFee;
            store.updateDistributionSetup(distributionNftId, setupInfo, KEEP_STATE());
        }

        if (isReferral) {
            referralInfo.usedReferrals += 1;
            store.updateReferral(referralId, referralInfo, KEEP_STATE());

            if (commissionAmount > 0) {
                distributorInfo.sumCommisions += commissionAmount;
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
