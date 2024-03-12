// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {InstanceAccessManager} from "../InstanceAccessManager.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {ISetup} from "../../instance/module/ISetup.sol";

import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
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

import {UFixed} from "../../types/UFixed.sol";
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
        distributorType = DistributorTypeLib.toDistributorType(distributionNftId, name);
        Key32 key32 = distributorType.toKey32();

        // FIXME: commission <= maxDiscountPercentage
        // FIXME: maxDiscountPercentage <= distributionFee
        
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
            data);

        instance.createDistributor(distributorNftId, info);
    }

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    ) external virtual
    {
        (,, IInstance instance) = _getAndVerifyCallingDistribution();

        IDistribution.DistributorInfo memory info = IDistribution.DistributorInfo(
            distributorType,
            true, // active
            data);

        instance.updateDistributor(distributorNftId, info, KEEP_STATE());
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
        require(bytes(code).length > 0, "ERROR:DSV-030:CODE_INVALID");
        require(expiryAt > zeroTimestamp(), "ERROR:DSV-031:EXPIRY_AT_ZERO");

        InstanceReader instanceReader = instance.getInstanceReader();
        IDistribution.DistributorInfo memory distributorTypeInfo = instanceReader.getDistributorInfo(distributorNftId);
        DistributorType distributorType = distributorTypeInfo.distributorType;
        IDistribution.DistributorTypeInfo memory distributorTypeData = instanceReader.getDistributorTypeInfo(distributorType);

        // FIXME: no require
        require(distributorTypeData.maxReferralCount >= maxReferrals, "ERROR:DSV-032:MAX_REFERRALS_EXCEEDED");
        require(distributorTypeData.minDiscountPercentage <= discountPercentage, "ERROR:DSV-033:DISCOUNT_TOO_LOW");
        require(distributorTypeData.maxDiscountPercentage >= discountPercentage, "ERROR:DSV-034:DISCOUNT_TOO_HIGH");
        require(expiryAt.toInt() - TimestampLib.blockTimestamp().toInt() <= distributorTypeData.maxReferralLifetime, "ERROR:DSV-035:EXPIRY_TOO_LONG");

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
        ReferralId referralId,
        uint256 premiumAmount
    )
        external
        virtual
        view 
        returns (uint256 feeAmount)
    {
        (,NftId distributionNftId, IInstance instance) = _getAndVerifyCallingDistribution();
        InstanceReader reader = instance.getInstanceReader();
        IDistribution.ReferralInfo memory info = reader.getReferralInfo(referralId);
        if(info.expiryAt > TimestampLib.blockTimestamp()) {
            revert ErrorIDistributionServiceInvalidReferralId(referralId);
        }

        // TODO: if referral code is not valid -> return distributionFee from setup
        // TODO: if referral code is valid, then return (distributionFee(fixed + pct) - referralDiscount(pct)) ... discount <= distributionFee
    }

    function referralIsValid(ReferralId referralId) public view returns (bool isValid) {
        (,NftId distributionNftId, IInstance instance) = _getAndVerifyCallingDistribution();
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

        require(objectType == DISTRIBUTION(), "ERROR:PRS-031:CALLER_NOT_DISTRUBUTION");
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
        require(objectNftId.gtz(), "ERROR:SRV-030:CALLER_UNKNOWN");
        IRegistry.ObjectInfo memory info = getRegistry().getObjectInfo(objectNftId);
        objectType = info.objectType;

        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(info.parentNftId);
        require(parentInfo.objectType == INSTANCE(), "ERROR:SRV-031:PARENT_NOT_INSTANCE");
        instance = IInstance(parentInfo.objectAddress);
    }

}
