// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, DISTRIBUTION} from "../types/ObjectType.sol";
import {IDistributionService} from "../instance/service/IDistributionService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {NftId} from "../types/NftId.sol";
import {ReferralId} from "../types/ReferralId.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";
import {IRegistry_new} from "../registry/IRegistry_new.sol";
import {IRegisterable_new} from "../shared/IRegisterable_new.sol";
import {Registerable_new} from "../shared/Registerable_new.sol";

contract Distribution is
    BaseComponent,
    IDistributionComponent
{

    Fee internal _initialDistributionFee;
    bool internal _isVerifying;

    IDistributionService private _distributionService;
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
        bool verifying,
        Fee memory distributionFee
    )
        BaseComponent(registry, instanceNftId, token, DISTRIBUTION())
    {
        _isVerifying = verifying;
        _initialDistributionFee = distributionFee;

        _distributionService = _instance.getDistributionService();
        _productService = _instance.getProductService();
    }


    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        _distributionService.setFees(distributionFee);
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
        Fee memory fee = getDistributionFee();
        (feeAmount,) = FeeLib.calculateFee(fee, netPremiumAmount);
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

    function referralIsValid(ReferralId referralId) external view returns (bool isValid) {
        // default is invalid
        return false;
    }

    /// @dev default distribution fee, ie when not using any valid referralId
    function getDistributionFee() public view returns (Fee memory distributionFee) {
        NftId productNftId = _instance.getProductNftId(getNftId());
        if (_instance.hasTreasuryInfo(productNftId)) {
            return _instance.getTreasuryInfo(productNftId).distributionFee;
        } else {
            return _initialDistributionFee;
        }
    }


    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying) {
        return _isVerifying;
    }

    // from IRegisterable

    /*function getDistributionInfo() public view returns(IRegistry_new.ObjectInfo memory, IDistributionComponent.DistributionComponentInfo memory)
    {
        return(getInfo(),
                DistributionComponentInfo(
                    _initialDistributionFee,
                    _isVerifying
                )            
        );
    }

    function getInitialDistributionInfo() public view returns(IRegistry_new.ObjectInfo memory, IDistributionComponent.DistributionComponentInfo memory)
    {
        return (getInitialInfo(),
                DistributionComponentInfo(
                    _initialDistributionFee,
                    _isVerifying
                )
        );
    }*/

    function getInfo() 
        public 
        view
        override (IRegisterable_new, Registerable_new)
        returns(IRegistry_new.ObjectInfo memory, bytes memory)
    {
        return(
            getRegistry().getObjectInfo(address(this)),
            abi.encode(
                _initialDistributionFee,
                _isVerifying   
            )         
        );
    }

    function getInitialInfo() 
        public 
        view
        override (IRegisterable_new, Registerable_new)
        returns(IRegistry_new.ObjectInfo memory, bytes memory)
    {
        (
            IRegistry_new.ObjectInfo memory info, 
            bytes memory data
        ) = super.getInitialInfo();

        return (
            info,
            abi.encode(
                _initialDistributionFee,
                _isVerifying
            )
        );
    }
}
