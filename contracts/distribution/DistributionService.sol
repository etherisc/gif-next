// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccountingService} from "../accounting/IAccountingService.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
// TODO cleanup
// import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {DistributorType, DistributorTypeLib} from "../type/DistributorType.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {ObjectType, ACCOUNTING, COMPONENT, DISTRIBUTION, INSTANCE, DISTRIBUTION, DISTRIBUTOR, REGISTRY} from "../type/ObjectType.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
// TODO PoolLib feels wrong, should likely go in a component type independent lib
import {PoolLib} from "../pool/PoolLib.sol";
import {ReferralId, ReferralStatus, ReferralLib, REFERRAL_OK, REFERRAL_ERROR_UNKNOWN, REFERRAL_ERROR_EXPIRED, REFERRAL_ERROR_EXHAUSTED} from "../type/Referral.sol";
import {Seconds} from "../type/Seconds.sol";
import {Service} from "../shared/Service.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


contract DistributionService is
    Service,
    IDistributionService
{
    IAccountingService private _accountingService;
    IComponentService private _componentService;
    IInstanceService private _instanceService;
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
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);

        _accountingService = IAccountingService(_getServiceAddress(ACCOUNTING()));
        _componentService = IComponentService(_getServiceAddress(COMPONENT()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        _registerInterface(type(IDistributionService).interfaceId);
    }


    function createDistributorType(
        string memory name,
        UFixed minDiscountPercentage,
        UFixed maxDiscountPercentage,
        UFixed commissionPercentage,
        uint32 maxReferralCount,
        Seconds maxReferralLifetime,
        bool allowSelfReferrals,
        bool allowRenewals,
        bytes memory data
    )
        external
        returns (DistributorType distributorType)
    {
        // _getAndVerifyActiveDistribution
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveDistribution();

        {
            NftId productNftId = getRegistry().getParentNftId(distributionNftId);
            IComponents.FeeInfo memory feeInfo = instance.getInstanceReader().getFeeInfo(productNftId);

            UFixed variableDistributionFees = feeInfo.distributionFee.fractionalFee;
            UFixed variableFeesPartsTotal = feeInfo.minDistributionOwnerFee.fractionalFee + commissionPercentage;

            if (variableFeesPartsTotal > variableDistributionFees) {
                revert ErrorDistributionServiceVariableFeesTooHight(variableDistributionFees.toInt1000(), variableFeesPartsTotal.toInt1000());
            }
            UFixed maxDiscountPercentageLimit = variableDistributionFees - variableFeesPartsTotal;

            if (maxDiscountPercentage > maxDiscountPercentageLimit) {
                revert ErrorDistributionServiceMaxDiscountTooHigh(maxDiscountPercentage.toInt1000(), maxDiscountPercentageLimit.toInt1000());
            }
        }

        distributorType = DistributorTypeLib.toDistributorType(distributionNftId, name);
        IDistribution.DistributorTypeInfo memory info = IDistribution.DistributorTypeInfo({
            name: name,
            distributionNftId: distributionNftId,
            minDiscountPercentage: minDiscountPercentage,
            maxDiscountPercentage: maxDiscountPercentage,
            commissionPercentage: commissionPercentage,
            maxReferralCount: maxReferralCount,
            maxReferralLifetime: maxReferralLifetime,
            allowSelfReferrals: allowSelfReferrals,
            allowRenewals: allowRenewals,
            data: data});

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
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveDistribution();
        _checkDistributionType(instance.getInstanceReader(), distributorType, distributionNftId);

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

        IDistribution.DistributorInfo memory info = IDistribution.DistributorInfo({
            distributorType: distributorType,
            active: true, 
            numPoliciesSold: 0,
            data: data});

        instance.getInstanceStore().createDistributor(distributorNftId, info);
    }

    function changeDistributorType(
        NftId distributorNftId,
        DistributorType newDistributorType,
        bytes memory data
    )
        external
        virtual
    {
        _checkNftType(distributorNftId, DISTRIBUTOR());
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveDistribution();
        _checkDistributionType(instance.getInstanceReader(), newDistributorType, distributionNftId);
        
        IDistribution.DistributorInfo memory distributorInfo = instance.getInstanceReader().getDistributorInfo(distributorNftId);
        distributorInfo.distributorType = newDistributorType;
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
        onlyNftOfType(distributorNftId, DISTRIBUTOR())
        returns (ReferralId referralId)
    {
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveDistribution();

        if (bytes(code).length == 0) {
            revert ErrorDistributionServiceInvalidReferral(code);
        }
        if (expiryAt.eqz() || expiryAt.lte(TimestampLib.blockTimestamp())) {
            revert ErrorDistributionServiceExpirationInvalid(expiryAt);
        }

        NftId distributorDistributionNftId = getRegistry().getParentNftId(distributorNftId);
        if (distributorDistributionNftId != distributionNftId) {
            revert ErrorDistributionServiceDistributorDistributionMismatch(distributorNftId, distributorDistributionNftId, distributionNftId);
        }

        {
            InstanceReader instanceReader = instance.getInstanceReader();
            DistributorType distributorType = instanceReader.getDistributorInfo(distributorNftId).distributorType;
            IDistribution.DistributorTypeInfo memory distributorTypeData = instanceReader.getDistributorTypeInfo(distributorType);

            if (distributorTypeData.maxReferralCount < maxReferrals) {
                revert ErrorDistributionServiceMaxReferralsExceeded(distributorTypeData.maxReferralCount);
            }
            if (distributorTypeData.minDiscountPercentage > discountPercentage) {
                revert ErrorDistributionServiceDiscountTooLow(distributorTypeData.minDiscountPercentage.toInt(), discountPercentage.toInt());
            }
            if (distributorTypeData.maxDiscountPercentage < discountPercentage) {
                revert ErrorDistributionServiceDiscountTooHigh(distributorTypeData.maxDiscountPercentage.toInt(), discountPercentage.toInt());
            }
            if (expiryAt.toInt() - TimestampLib.blockTimestamp().toInt() > distributorTypeData.maxReferralLifetime.toInt()) {
                revert ErrorDistributionServiceExpiryTooLong(distributorTypeData.maxReferralLifetime, expiryAt);
            }
        }

        {
            referralId = ReferralLib.toReferralId(distributionNftId, code);
            IDistribution.ReferralInfo memory info = IDistribution.ReferralInfo({
                distributionNftId: distributionNftId,
                distributorNftId: distributorNftId,
                referralCode: code,
                discountPercentage: discountPercentage,
                maxReferrals: maxReferrals,
                usedReferrals: 0, 
                expiryAt: expiryAt,
                data: data
            });

            instance.getInstanceStore().createReferral(referralId, info);
        }
    }

    /// @inheritdoc IDistributionService
    function processReferral(
        NftId distributionNftId, 
        ReferralId referralId
    ) 
        external
        virtual
        restricted()
        onlyNftOfType(distributionNftId, DISTRIBUTION())
    {
        if (referralIsValid(distributionNftId, referralId)) {
            IInstance instance = _getInstanceForDistribution(getRegistry(), distributionNftId);

            // update book keeping for referral info
            IDistribution.ReferralInfo memory referralInfo = instance.getInstanceReader().getReferralInfo(referralId);
            referralInfo.usedReferrals += 1;
            instance.getInstanceStore().updateReferral(referralId, referralInfo, KEEP_STATE());
        }
    }

    function processSale(
        NftId distributionNftId, // assume always of distribution type
        ReferralId referralId,
        IPolicy.PremiumInfo memory premium
    )
        external
        virtual
        restricted()
        onlyNftOfType(distributionNftId, DISTRIBUTION())
    {
        IInstance instance = _getInstanceForDistribution(getRegistry(), distributionNftId);
        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // get distribution owner fee amount
        Amount distributionOwnerFee = premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount;

        // update referral/distributor info if applicable
        if (referralIsValid(distributionNftId, referralId)) {

            // increase distribution balance by commission amount and distribution owner fee
            Amount commissionAmount = premium.commissionAmount;
            _accountingService.increaseDistributionBalance(store, distributionNftId, commissionAmount, distributionOwnerFee);

            // update book keeping for referral info
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);

            _accountingService.increaseDistributorBalance(store, referralInfo.distributorNftId, AmountLib.zero(), commissionAmount);

            // update book keeping for distributor info
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            distributorInfo.numPoliciesSold += 1;
            store.updateDistributor(referralInfo.distributorNftId, distributorInfo, KEEP_STATE());
        } else {
            // increase distribution balance by distribution owner fee
            _accountingService.increaseDistributionBalance(store, distributionNftId, AmountLib.zero(), distributionOwnerFee);
        }
    }

    /// @inheritdoc IDistributionService
    function withdrawCommission(NftId distributorNftId, Amount amount) 
        public 
        virtual
        // TODO: restricted() (once #462 is done)
        onlyNftOfType(distributorNftId, DISTRIBUTOR())
        returns (Amount withdrawnAmount) 
    {
        (NftId distributionNftId, IInstance instance) = _getAndVerifyActiveDistribution();
        InstanceReader reader = instance.getInstanceReader();
        
        IComponents.ComponentInfo memory distributionInfo = reader.getComponentInfo(distributionNftId);
        // address distributionWallet = distributionInfo.tokenHandler.getWallet();
        
        Amount commissionAmount = reader.getFeeAmount(distributorNftId);
        
        // determine withdrawn amount
        withdrawnAmount = amount;
        if (withdrawnAmount >= AmountLib.max()) {
            withdrawnAmount = commissionAmount;
        } else {
            if (withdrawnAmount > commissionAmount) {
                revert ErrorDistributionServiceCommissionWithdrawAmountExceedsLimit(withdrawnAmount, commissionAmount);
            }
        }

        // decrease fee counters by withdrawnAmount and update distributor info
        {
            InstanceStore store = instance.getInstanceStore();
            // decrease fee counter for distribution balance
            _accountingService.decreaseDistributionBalance(store, distributionNftId, withdrawnAmount, AmountLib.zero());
            // decrease fee counter for distributor fee
            _accountingService.decreaseDistributorBalance(store, distributorNftId, AmountLib.zero(), withdrawnAmount);
        }

        // transfer amount to distributor
        {
            address distributor = getRegistry().ownerOf(distributorNftId);
            emit LogDistributionServiceCommissionWithdrawn(distributorNftId, distributor, address(distributionInfo.tokenHandler.TOKEN()), withdrawnAmount);
            distributionInfo.tokenHandler.pushToken(distributor, withdrawnAmount);
        }
    }

    function referralIsValid(NftId distributionNftId, ReferralId referralId) 
        public 
        view 
        onlyNftOfType(distributionNftId, DISTRIBUTION())
        returns (bool isValid) 
    {
        if (distributionNftId.eqz() || referralId.eqz()) {
            return false;
        }

        IInstance instance = _getInstanceForDistribution(getRegistry(), distributionNftId);
        IDistribution.ReferralInfo memory info = instance.getInstanceReader().getReferralInfo(referralId);

        if (info.distributorNftId.eqz()) {
            return false;
        }

        // ensure the referral was created on the same distribution
        if(info.distributionNftId != distributionNftId) {
            revert ErrorDistributionServiceReferralDistributionMismatch(referralId, info.distributionNftId, distributionNftId);
        }

        isValid = info.expiryAt.eqz() || (info.expiryAt.gtz() && TimestampLib.blockTimestamp() <= info.expiryAt);
        isValid = isValid && info.usedReferrals < info.maxReferrals;
    }


    function getDiscountPercentage(
        InstanceReader instanceReader,
        ReferralId referralId
    )
        external
        virtual
        view 
        returns (
            UFixed discountPercentage, 
            ReferralStatus status
        )
    { 
        IDistribution.ReferralInfo memory info = instanceReader.getReferralInfo(
            referralId);        

        if (info.expiryAt.eqz()) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_UNKNOWN());
        }

        if (info.expiryAt < TimestampLib.blockTimestamp()) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_EXPIRED());
        }

        if (info.usedReferrals >= info.maxReferrals) {
            return (
                UFixedLib.zero(),
                REFERRAL_ERROR_EXHAUSTED());
        }

        return (
            info.discountPercentage,
            REFERRAL_OK()
        );

    }


    function _checkDistributionType(InstanceReader instanceReader, DistributorType distributorType, NftId expectedDistributionNftId) 
        internal
        view 
    {
        // enfore distributor type belongs to the calling distribution
        NftId distributorTypeDistributionNftId = instanceReader.getDistributorTypeInfo(distributorType).distributionNftId;

        if (distributorTypeDistributionNftId != expectedDistributionNftId) {
            revert ErrorDistributionServiceDistributorTypeDistributionMismatch(distributorType, distributorTypeDistributionNftId, expectedDistributionNftId);
        }
    }


    // TODO cleanup
    function _getInstanceForDistribution(IRegistry registry, NftId distributionNftId)
        internal
        view
        returns(IInstance instance)
    {
        return PoolLib.getInstanceForComponent(registry, distributionNftId);
    }


    function _getAndVerifyActiveDistribution()
        internal
        virtual
        view
        returns (
            NftId poolNftId,
            IInstance instance
        )
    {
        return PoolLib.getAndVerifyActiveComponent(getRegistry(), msg.sender, DISTRIBUTION());
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return DISTRIBUTION();
    }
}