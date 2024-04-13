// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Distribution} from "../../contracts/distribution/Distribution.sol";

import {Fee} from "../../contracts/type/Fee.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {Timestamp} from "../../contracts/type/Timestamp.sol";
import {UFixed} from "../../contracts/type/UFixed.sol";

contract SimpleDistribution is Distribution {
    
    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee,
        address initialOwner
    ) 
    {
        initialize(
            registry,
            instanceNftId,
            "SimpleDistribution",
            token,
            minDistributionOwnerFee,
            distributionFee,
            initialOwner);
    }

    function initialize(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee,
        address initialOwner
    )
        public
        virtual
        initializer()
    {
        initializeDistribution(
            registry,
            instanceNftId,
            name,
            token,
            minDistributionOwnerFee,
            distributionFee,
            initialOwner,
            ""
        );
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
        returns (ReferralId referralId)
    {
        return _createReferral(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            expiryAt,
            data);
    }
}