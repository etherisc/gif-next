// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {DISTRIBUTION} from "../types/ObjectType.sol";
import {IDistributionService} from "../instance/service/IDistributionService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {NftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {ReferralId} from "../types/Referral.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {BaseComponent} from "./BaseComponent.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

contract Distribution is
    BaseComponent,
    IDistributionComponent
{
    using NftIdLib for NftId;

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
        NftId productNftId,
        // TODO refactor into tokenNftId
        address token,
        bool verifying,
        Fee memory distributionFee,
        address initialOwner
    )
        BaseComponent(registry, instanceNftId, productNftId, token, DISTRIBUTION(), true, initialOwner)
    {
        _isVerifying = verifying;
        _initialDistributionFee = distributionFee;

        // TODO: reactivate when services are available again
        // _distributionService = _instance.getDistributionService();
        // _productService = _instance.getProductService();

        _registerInterface(type(IDistributionComponent).interfaceId);
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
        ISetup.DistributionSetupInfo memory setupInfo = getSetupInfo();
        Fee memory fee = setupInfo.distributionFee;
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

    function getSetupInfo() public view returns (ISetup.DistributionSetupInfo memory setupInfo) {
        if (getNftId().eq(zeroNftId())) {
            return ISetup.DistributionSetupInfo(
                _productNftId,
                TokenHandler(address(0)),
                _initialDistributionFee,
                _isVerifying,
                address(0)
            );
        } 

        InstanceReader reader = _instance.getInstanceReader();
        return reader.getDistributionSetupInfo(getNftId());
    }

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying) {
        return _isVerifying;
    }

    // from IRegisterable

    function getInitialInfo() 
        public 
        view
        override (IRegisterable, Registerable)
        returns(IRegistry.ObjectInfo memory, bytes memory)
    {
        (
            IRegistry.ObjectInfo memory info, 
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
