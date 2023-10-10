// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, DISTRIBUTION} from "../types/ObjectType.sol";
import {IProductService} from "../instance/service/IProductService.sol";
// import {IPoolService} from "../instance/service/IPoolService.sol";
import {NftId} from "../types/NftId.sol";
import {ReferralId} from "../types/ReferralId.sol";
// import {Fee} from "../types/Fee.sol";
// import {UFixed} from "../types/UFixed.sol";
import {BaseComponent} from "./BaseComponent.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";

contract Distribution is
    BaseComponent,
    IDistributionComponent
{

    bool internal _isVerifying;

    // only relevant to protect callback functions for "active" pools
    IProductService private _productService;

    modifier onlyProductService() {
        require(
            msg.sender == address(_productService), 
            "ERROR:POL-002:NOT_PRODUCT_SERVICE");
        _;
    }

    constructor(
        address registry,
        NftId instanceNftId,
        // TODO refactor into tokenNftId
        address token,
        bool verifying
    )
        BaseComponent(registry, instanceNftId, token)
    {
        _isVerifying = verifying;
        _productService = _instance.getProductService();
    }


    function calculateFeeAmount(
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

    function processSale(
        ReferralId referralId,
        uint256 feeAmount
    )
        external
        onlyProductService
        virtual override
    {
        // default is no action
    }

    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    )
        external
        onlyProductService
        virtual override
    {
        // default is no action
    }


    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying) {
        return _isVerifying;
    }

    // from registerable
    function getType() public pure override returns (ObjectType) {
        return DISTRIBUTION();
    }
}
