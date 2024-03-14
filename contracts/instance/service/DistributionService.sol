// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceAccessManager} from "../InstanceAccessManager.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {DISTRIBUTION_OWNER_ROLE} from "../../types/RoleId.sol";
import {KEEP_STATE} from "../../types/StateId.sol";
import {ObjectType, DISTRIBUTION, INSTANCE, DISTRIBUTION, DISTRIBUTOR} from "../../types/ObjectType.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";
import {ComponentService} from "../base/ComponentService.sol";
import {InstanceService} from "../InstanceService.sol";
import {IComponent} from "../../components/IComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IDistributionService} from "./IDistributionService.sol";

import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {DistributorType, DistributorTypeLib} from "../../types/DistributorType.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../../types/Referral.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {Key32} from "../../types/Key32.sol";
import {IDistribution} from "../module/IDistribution.sol";


contract DistributionService is
    ComponentService,
    IDistributionService
{
    using NftIdLib for NftId;
    using TimestampLib for Timestamp;
    using UFixedLib for UFixed;
    using FeeLib for Fee;

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
        initializeService(registryAddress, owner);
        registerInterface(type(IDistributionService).interfaceId);
    }

    function getDomain() public pure override(Service, IService) returns(ObjectType) {
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

        instance.createDistributionSetup(distributionNftId, distribution.getSetupInfo());
        getInstanceService().createGifTarget(instanceNftId, distributionAddress, distribution.getName());
        getInstanceService().grantDistributionDefaultPermissions(instanceNftId, distributionAddress, distribution.getName());
    }

    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory info , IInstance instance) = _getAndVerifyComponentInfoAndInstance(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();
        NftId distributionNftId = info.nftId;

        ISetup.DistributionSetupInfo memory distSetupInfo = instanceReader.getDistributionSetupInfo(distributionNftId);
        distSetupInfo.distributionFee = distributionFee;
        
        instance.updateDistributionSetup(distributionNftId, distSetupInfo, KEEP_STATE());
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
        (,NftId distributionNftId, IInstance instance) = _getAndVerifyCallingDistribution();

        {
            if (commissionPercentage > maxDiscountPercentage) {
                revert ErrorIDistributionServiceCommissionTooHigh(commissionPercentage.toInt(), maxDiscountPercentage.toInt());
            }

            ISetup.DistributionSetupInfo memory setupInfo = instance.getInstanceReader().getDistributionSetupInfo(distributionNftId);
            if (maxDiscountPercentage > setupInfo.distributionFee.fractionalFee) {
                revert ErrorIDistributionServiceMaxDiscountTooHigh(maxDiscountPercentage.toInt(), setupInfo.distributionFee.fractionalFee.toInt());
            }
        }
        
        distributorType = DistributorTypeLib.toDistributorType(distributionNftId, name);
        Key32 key32 = distributorType.toKey32();

        if(!instance.exists(key32)) {
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

            instance.createDistributorType(key32, info);
        }
    }

    function createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    ) external returns (NftId distributorNftId)
    {
        (, NftId distributionNftId, IInstance instance) = _getAndVerifyCallingDistribution();

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

        instance.createDistributor(distributorNftId, info);
    }

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    ) external virtual
    {
        (,, IInstance instance) = _getAndVerifyCallingDistribution();
        InstanceReader instanceReader = instance.getInstanceReader();
        IDistribution.DistributorInfo memory distributorInfo = instanceReader.getDistributorInfo(distributorNftId);
        distributorInfo.distributorType = distributorType;
        distributorInfo.data = data;
        instance.updateDistributor(distributorNftId, distributorInfo, KEEP_STATE());
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
        (,NftId distributionNftId, IInstance instance) = _getAndVerifyCallingDistribution();

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

        instance.createReferral(referralId.toKey32(), info);
        return referralId;
    }

    function processSale(
        ReferralId referralId,
        uint256 premiumAmount
    )
        external
        virtual
    {
        // TODO: fetch referral
        // TODO: update referral usage numbers
        // TODO: update bookkeeping
        // TODO: calculate commission for distributor
        // TODO: calculate fee for distribution owner
        // TODO: updates sum of commission per distributor -> DistributorInfo
        // TODO: updates sum of fee per distribution owner
        revert("NOT_IMPLEMENTED_YET");
    }

    function calculateFeeAmount(
        NftId distributionNftId,
        ReferralId referralId,
        uint256 netPremiumAmount
    )
        external
        virtual
        view 
        returns (uint256 distributionFeeAmount, uint256 commissionAmount)
    {
        (, IInstance instance) = _getAndVerifyDistribution(distributionNftId);
        InstanceReader reader = instance.getInstanceReader();

        // calculate fee based on the distribution components fee
        ISetup.DistributionSetupInfo memory setupInfo = reader.getDistributionSetupInfo(distributionNftId);
        Fee memory fee = setupInfo.distributionFee;
        (distributionFeeAmount,) = fee.calculateFee(netPremiumAmount);

        if (referralIsValid(distributionNftId, referralId)) {
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            IDistribution.DistributorTypeInfo memory distributorTypeInfo = reader.getDistributorTypeInfo(distributorInfo.distributorType);
            commissionAmount = UFixedLib.toUFixed(netPremiumAmount).mul(distributorTypeInfo.commissionPercentage).toInt();
        } 
    }

    function referralIsValid(NftId distributionNftId, ReferralId referralId) public view returns (bool isValid) {
        (address distributionAddress, IInstance instance) = _getAndVerifyDistribution(distributionNftId);
        IDistribution.ReferralInfo memory info = instance.getInstanceReader().getReferralInfo(referralId);

        if (info.distributorNftId.eqz()) {
            return false;
        }

        isValid = info.expiryAt.eqz() || (info.expiryAt.gtz() && TimestampLib.blockTimestamp() <= info.expiryAt);
        isValid = isValid && info.usedReferrals < info.maxReferrals;
    }

    function _getAndVerifyCallingDistribution()
        internal
        view
        returns(
            address distributionAddress,
            NftId distributionNftId,
            IInstance instance
        )
    {
        ObjectType objectType;
        (
            distributionAddress,
            distributionNftId,
            objectType,
            instance
        ) = _getAndVerifyCaller();

        if(objectType != DISTRIBUTION()) {
            revert ErrorIDistributionServiceCallerNotDistributor(msg.sender);
        }
    }

    function _getAndVerifyDistribution(NftId distributionNftId)
        internal
        view
        returns(
            address distributionAddress,
            IInstance instance
        )
    {
        IRegistry.ObjectInfo memory info = getRegistry().getObjectInfo(distributionNftId);
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(info.parentNftId);
        if (parentInfo.objectType != INSTANCE()) {
            revert ErrorIDistributionServiceParentNftIdNotInstance(distributionNftId, info.parentNftId);
        }
        instance = IInstance(parentInfo.objectAddress);
    }

    function _getAndVerifyCaller()
        internal
        view
        returns(
            address objectAddress,
            NftId objectNftId,
            ObjectType objectType,
            IInstance instance
        )
    {
        objectAddress = msg.sender;
        objectNftId = getRegistry().getNftId(objectAddress);
        if ( objectNftId.eqz()) {
            revert ErrorIServiceCallerUnknown(objectAddress);
        }
        IRegistry.ObjectInfo memory info = getRegistry().getObjectInfo(objectNftId);
        objectType = info.objectType;

        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(info.parentNftId);
        if (parentInfo.objectType != INSTANCE()) {
            revert ErrorIDistributionServiceParentNftIdNotInstance(objectNftId, info.parentNftId);
        }
        instance = IInstance(parentInfo.objectAddress);
    }

}
