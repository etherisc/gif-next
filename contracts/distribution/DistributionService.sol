// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {ObjectType, COMPONENT, DISTRIBUTION, INSTANCE, DISTRIBUTION, DISTRIBUTOR, REGISTRY} from "../type/ObjectType.sol";
import {ComponentVerifyingService} from "../shared/ComponentVerifyingService.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType, DistributorTypeLib} from "../type/DistributorType.sol";
import {ReferralId, ReferralLib} from "../type/Referral.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";


contract DistributionService is
    ComponentVerifyingService,
    IDistributionService
{
    IComponentService private _componentService;
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

        _componentService = IComponentService(_getServiceAddress(COMPONENT()));
        _instanceService = IInstanceService(_getServiceAddress(INSTANCE()));
        _registryService = IRegistryService(_getServiceAddress(REGISTRY()));

        registerInterface(type(IDistributionService).interfaceId);
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
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
        InstanceReader instanceReader = instance.getInstanceReader();

        {
            NftId productNftId = _getProductNftId(instanceReader, distributionNftId);
            IComponents.ProductInfo memory productInfo = instance.getInstanceReader().getProductInfo(productNftId);

            UFixed variableDistributionFees = productInfo.distributionFee.fractionalFee;
            UFixed variableFeesPartsTotal = productInfo.minDistributionOwnerFee.fractionalFee + commissionPercentage;

            if (variableFeesPartsTotal > variableDistributionFees) {
                revert ErrorDistributionServiceVariableFeesTooHight(variableDistributionFees.toInt1000(), variableFeesPartsTotal.toInt1000());
            }
            UFixed maxDiscountPercentageLimit = variableDistributionFees - variableFeesPartsTotal;

            if (maxDiscountPercentage.gt(maxDiscountPercentageLimit)) {
                revert ErrorDistributionServiceMaxDiscountTooHigh(maxDiscountPercentage.toInt1000(), maxDiscountPercentageLimit.toInt1000());
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

    /// @inheritdoc IDistributionService
    function processReferral(
        NftId distributionNftId, 
        ReferralId referralId
    ) 
        external
        virtual
        restricted
    {
        if (referralIsValid(distributionNftId, referralId)) {
            IInstance instance = _getInstanceForDistribution(distributionNftId);
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
        restricted
    {
        IInstance instance = _getInstanceForDistribution(distributionNftId);
        InstanceReader reader = instance.getInstanceReader();
        InstanceStore store = instance.getInstanceStore();

        // get distribution owner fee amount
        Amount distributionOwnerFee = AmountLib.toAmount(premium.distributionOwnerFeeFixAmount + premium.distributionOwnerFeeVarAmount);

        // update referral/distributor info if applicable
        if (referralIsValid(distributionNftId, referralId)) {

            // increase distribution balance by commission amount and distribution owner fee
            Amount commissionAmount = AmountLib.toAmount(premium.commissionAmount);
            _componentService.increaseDistributionBalance(store, distributionNftId, commissionAmount, distributionOwnerFee);

            // update book keeping for referral info
            IDistribution.ReferralInfo memory referralInfo = reader.getReferralInfo(referralId);

            _componentService.increaseDistributorBalance(store, referralInfo.distributorNftId, AmountLib.zero(), commissionAmount);

            // update book keeping for distributor info
            IDistribution.DistributorInfo memory distributorInfo = reader.getDistributorInfo(referralInfo.distributorNftId);
            distributorInfo.numPoliciesSold += 1;
            store.updateDistributor(referralInfo.distributorNftId, distributorInfo, KEEP_STATE());
        } else {
            // increase distribution balance by distribution owner fee
            _componentService.increaseDistributionBalance(store, distributionNftId, AmountLib.zero(), distributionOwnerFee);
        }
    }

    /// @inheritdoc IDistributionService
    function withdrawCommission(NftId distributorNftId, Amount amount) 
        public 
        virtual
        // TODO: restricted() (once #462 is done)
        returns (Amount withdrawnAmount) 
    {
        (NftId distributionNftId,, IInstance instance) = _getAndVerifyActiveComponent(DISTRIBUTION());
        InstanceReader reader = instance.getInstanceReader();
        
        IComponents.ComponentInfo memory distributionInfo = reader.getComponentInfo(distributionNftId);
        address distributionWallet = distributionInfo.wallet;
        
        Amount commissionAmount = reader.getFeeAmount(distributorNftId);
        
        // determine withdrawn amount
        withdrawnAmount = amount;
        if (withdrawnAmount.gte(AmountLib.max())) {
            withdrawnAmount = commissionAmount;
        } else {
            if (withdrawnAmount.gt(commissionAmount)) {
                revert ErrorDistributionServiceCommissionWithdrawAmountExceedsLimit(withdrawnAmount, commissionAmount);
            }
        }

        // decrease fee counters by withdrawnAmount and update distributor info
        {
            InstanceStore store = instance.getInstanceStore();
            // decrease fee counter for distribution balance
            _componentService.decreaseDistributionBalance(store, distributionNftId, withdrawnAmount, AmountLib.zero());
            // decrease fee counter for distributor fee
            _componentService.decreaseDistributorBalance(store, distributorNftId, AmountLib.zero(), withdrawnAmount);
        }

        // transfer amount to distributor
        {
            address distributor = getRegistry().ownerOf(distributorNftId);
            emit LogDistributionServiceCommissionWithdrawn(distributorNftId, distributor, address(distributionInfo.token), withdrawnAmount);
            distributionInfo.tokenHandler.distributeTokens(distributionWallet, distributor, withdrawnAmount);
        }
    }

    function referralIsValid(NftId distributionNftId, ReferralId referralId) public view returns (bool isValid) {
        if (distributionNftId.eqz() || referralId.eqz()) {
            return false;
        }

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

    function _getDomain() internal pure override returns(ObjectType) {
        return DISTRIBUTION();
    }
}