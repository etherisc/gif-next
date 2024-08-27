// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";
import {IDistributionService} from "./IDistributionService.sol";

import {Amount} from "../type/Amount.sol";
import {COMPONENT, DISTRIBUTION, DISTRIBUTOR} from "../type/ObjectType.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Fee} from "../type/Fee.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../type/Referral.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";


abstract contract Distribution is
    InstanceLinkedComponent,
    IDistributionComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Distribution")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant DISTRIBUTION_STORAGE_LOCATION_V1 = 0xaab7c5ea03d290056d6c060e0833d3ebcbe647f7694616a2ec52738a64b2f900;

    struct DistributionStorage {
        IComponentService _componentService;
        IDistributionService _distributionService;
    }

    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    )
        external
        virtual
        restricted()
    {
        // default is no action
    }


    /// @inheritdoc IDistributionComponent
    function withdrawCommission(NftId distributorNftId, Amount amount) 
        external 
        virtual
        restricted()
        onlyNftOfType(distributorNftId, DISTRIBUTOR())
        onlyNftOwner(distributorNftId)
        returns (Amount withdrawnAmount) 
    {
        return _withdrawCommission(distributorNftId, amount);
    }

    function getDiscountPercentage(string memory referralCode)
        external
        view
        returns (
            UFixed discountPercentage, 
            ReferralStatus status
        )
    {
        ReferralId referralId = getReferralId(referralCode);
        return _getInstanceReader().getDiscountPercentage(referralId);
    }


    function getReferralId(
        string memory referralCode
    )
        public
        view 
        returns (ReferralId referralId)
    {
        return ReferralLib.toReferralId(
            getNftId(), 
            referralCode);      
    }


    function calculateRenewalFeeAmount(
        ReferralId referralId,
        uint256 netPremiumAmount
    )
        external
        view
        virtual override
        returns (uint256 feeAmount)
    {
        // default is no fees
        return 0 * netPremiumAmount;
    }


    /// @dev Returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external pure returns (bool verifying) {
        return true;
    }


    function _initializeDistribution(
        address registry,
        NftId productNftId,
        IAuthorization authorization, 
        address initialOwner,
        string memory name,
        address token,
        bytes memory componentData // component specifidc data 
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeInstanceLinkedComponent(
            registry, 
            productNftId, 
            name, 
            token, 
            DISTRIBUTION(), 
            authorization,
            true, 
            initialOwner, 
            componentData);

        DistributionStorage storage $ = _getDistributionStorage();
        $._distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION())); 
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        _registerInterface(type(IDistributionComponent).interfaceId);
    }

    /// @dev Sets the distribution fees to the provided values.
    function _setFees(
        Fee memory distributionFee,
        Fee memory minDistributionOwnerFee
    )
        internal
        virtual
    {
        _getDistributionStorage()._componentService.setDistributionFees(
            distributionFee, 
            minDistributionOwnerFee);
    }

    /// @dev Creates a new distributor type using the provided parameters.
    function _createDistributorType(
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
        internal
        virtual
        returns (DistributorType distributorType)
    {
        DistributionStorage storage $ = _getDistributionStorage();
        distributorType = $._distributionService.createDistributorType(
            name,
            minDiscountPercentage,
            maxDiscountPercentage,
            commissionPercentage,
            maxReferralCount,
            maxReferralLifetime,
            allowSelfReferrals,
            allowRenewals,
            data);
    }

    /// @dev Turns the provided account into a new distributor of the specified type.
    function _createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    )
        internal
        virtual
        returns(NftId distributorNftId)
    {
        DistributionStorage storage $ = _getDistributionStorage();

        distributorNftId = $._distributionService.createDistributor(
            distributor,
            distributorType,
            data);
    }

    /// @dev Uptates the distributor type for the specified distributor.
    function _changeDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    )
        internal
        virtual
    {
        DistributionStorage storage $ = _getDistributionStorage();
        $._distributionService.changeDistributorType(
            distributorNftId,
            distributorType,
            data);
    }

    /// @dev Create a new referral code for the provided distributor.
    function _createReferral(
        NftId distributorNftId,
        string memory code,
        UFixed discountPercentage,
        uint32 maxReferrals,
        Timestamp expiryAt,
        bytes memory data
    )
        internal
        virtual
        returns (ReferralId referralId)
    {
        DistributionStorage storage $ = _getDistributionStorage();
        referralId = $._distributionService.createReferral(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            expiryAt,
            data);
    }

    function _withdrawCommission(NftId distributorNftId, Amount amount) 
        internal
        returns (Amount withdrawnAmount) 
    {
        return _getDistributionStorage()._distributionService.withdrawCommission(distributorNftId, amount);
    }

    function _nftTransferFrom(address from, address to, uint256 tokenId, address operator) internal virtual override {
        // keep track of distributor nft owner
        emit LogDistributorUpdated(to, operator);
    }

    function _getDistributionStorage() private pure returns (DistributionStorage storage $) {
        assembly {
            $.slot := DISTRIBUTION_STORAGE_LOCATION_V1
        }
    }
}
