// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../../type/Amount.sol";
import {BasicDistribution} from "../../distribution/BasicDistribution.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {NftId} from "../../type/NftId.sol";
import {ReferralId} from "../../type/Referral.sol";
import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../type/UFixed.sol";


contract SimpleDistribution is
    BasicDistribution
{
    
    constructor(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner,
        address token
    ) 
    {
        initialize(
            registry,
            productNftId,
            authorization,
            initialOwner,
            "SimpleDistribution",
            token);
    }

    function initialize(
        address registry,
        NftId productNftId,
        IAuthorization authorization,
        address initialOwner,
        string memory name,
        address token
    )
        public
        virtual
        initializer()
    {
        _initializeBasicDistribution(
            registry,
            productNftId,
            authorization,
            initialOwner,
            name,
            token);
    }

    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }

    /**
     * @dev create referral codes. This is required for testing only to provide a distributor that is not the message sender. 
     */
    function createReferral2(
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
        return _createReferral(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            expiryAt,
            data); // data
    }

}