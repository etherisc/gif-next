// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAuthorization} from "../authorization/IAuthorization.sol";

import {Distribution} from "./Distribution.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {DISTRIBUTOR} from "../type/ObjectType.sol";
import {Fee} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";


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
        Seconds maxReferralLifetime,
        bool allowSelfReferrals,
        bool allowRenewals,
        bytes memory data
    )
        external
        virtual
        restricted()
        onlyOwner()
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
        restricted()
        onlyOwner()
        returns(NftId distributorNftId)
    {
        return _createDistributor(distributor, distributorType, data);
    }

    function changeDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    )
        external
        virtual
        restricted()
        onlyOwner()
        onlyNftOfType(distributorNftId, DISTRIBUTOR())
    {
        _changeDistributorType(distributorNftId, distributorType, data);
    }

    /**
     * @dev lets distributors create referral codes.
     * referral codes need to be unique
     */
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
        restricted()
        onlyNftOwner(distributorNftId)
        returns (ReferralId referralId)
    {
        _checkNftType(distributorNftId, DISTRIBUTOR());
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
        string memory name
    )
        internal
        virtual
        onlyInitializing()
    {
        __Distribution_init(
            registry, 
            instanceNftId, 
            authorization,
            false,
            initialOwner, 
            name); 
    }
}
