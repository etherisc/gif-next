// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
// import {IPolicy} from "../../instance/module/IPolicy.sol";

import {Amount} from "../../type/Amount.sol";
import {BasicProduct} from "../../product/BasicProduct.sol";
// import {ClaimId} from "../../type/ClaimId.sol";
import {FeeLib} from "../../type/Fee.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
// import {PayoutId} from "../../type/PayoutId.sol";
// import {POLICY, BUNDLE} from "../../type/ObjectType.sol";
// import {ReferralLib} from "../../type/Referral.sol";
// import {RiskId, RiskIdLib} from "../../type/RiskId.sol";
// import {Seconds} from "../../type/Seconds.sol";
// import {Timestamp, TimestampLib} from "../../type/Timestamp.sol";
// import {UFixed, UFixedLib} from "../../type/UFixed.sol";


/// @dev FlightProduct implements the flight delay product.
contract FlightProduct is
    BasicProduct
{   

    struct Risk {
        bytes32 carrierFlightNumber; // migrate to Str?
        bytes32 departureYearMonthDay;
        uint256 departureTime; // migrate to timestamp
        uint256 arrivalTime; // migrate to timestamp
        uint256 delayInMinutes; // migrate to seconds
        uint8 delay; // what is this?
        uint256 estimatedMaxTotalPayout; // migrate to amount
        uint256 premiumMultiplier; // what is this? UFixed?
        uint256 weight; // what is this? UFixed?
    }

    constructor(
        address registry,
        NftId instanceNftid,
        string memory componentName,
        IAuthorization authorization
    )
    {
        address initialOwner = msg.sender;

        _initialize(
            registry,
            instanceNftid,
            componentName,
            authorization,
            initialOwner);
    }

    function _initialize(
        address registry,
        NftId instanceNftId,
        string memory componentName,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicProduct(
            registry,
            instanceNftId,
            componentName,
            IComponents.ProductInfo({
                isProcessingFundedClaims: false,
                isInterceptingPolicyTransfers: false,
                hasDistribution: false,
                expectedNumberOfOracles: 0,
                numberOfOracles: 0,
                poolNftId: NftIdLib.zero(),
                distributionNftId: NftIdLib.zero(),
                oracleNftId: new NftId[](0)
            }), 
            IComponents.FeeInfo({
                productFee: FeeLib.zero(),
                processingFee: FeeLib.zero(),
                distributionFee: FeeLib.zero(),
                minDistributionOwnerFee: FeeLib.zero(),
                poolFee: FeeLib.zero(),
                stakingFee: FeeLib.zero(),
                performanceFee: FeeLib.zero()
            }),
            authorization,
            initialOwner);  // number of oracles
    }

    function approveTokenHandler(IERC20Metadata token, Amount amount) external restricted() onlyOwner() { _approveTokenHandler(token, amount); }
    function setLocked(bool locked) external onlyOwner() { _setLocked(locked); }
    function setWallet(address newWallet) external restricted() onlyOwner() { _setWallet(newWallet); }
}