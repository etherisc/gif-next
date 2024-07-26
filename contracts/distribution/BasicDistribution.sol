// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Distribution} from "./Distribution.sol";
import {DISTRIBUTOR} from "../type/ObjectType.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {Fee} from "../type/Fee.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Timestamp} from "../type/Timestamp.sol";


contract BasicDistribution is
    Distribution
{

    function setFees(
        Fee memory distributionFee,
        Fee memory minDistributionOwnerFee
    )
        external
        virtual
        onlyOwner()
        restricted()
    {
        _setFees(
            distributionFee, 
            minDistributionOwnerFee);
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
        virtual
        onlyOwner()
        restricted()
        returns (DistributorType distributorType)
    {
        return _createDistributorType(
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

    function createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    )
        external
        virtual
        onlyOwner()
        restricted()
        returns(NftId distributorNftId)
    {
        return _createDistributor(distributor, distributorType, data);
    }

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    )
        external
        virtual
        onlyOwner()
        onlyNftOfType(distributorNftId, DISTRIBUTOR())
        restricted()
    {
        _updateDistributorType(distributorNftId, distributorType, data);
    }

    /**
     * @dev lets distributors create referral codes.
     * referral codes need to be unique
     */
    function createReferral(
        string memory code,
        UFixed discountPercentage,
        uint32 maxReferrals,
        Timestamp expiryAt,
        bytes memory data
    )
        external
        virtual
        onlyDistributor()
        restricted()
        returns (ReferralId referralId)
    {
        NftId distributorNftId = getDistributorNftId(msg.sender);
        return _createReferral(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            expiryAt,
            data); // data
    }

    function _initializeBasicDistribution(
        address registry,
        NftId instanceNftId,
        IAuthorization authorization, 
        address initialOwner,
        string memory name,
        address token
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeDistribution(
            registry, 
            instanceNftId, 
            authorization,
            initialOwner, 
            name, 
            token, 
            "", // registry data
            ""); // component specifc data
    }
}
