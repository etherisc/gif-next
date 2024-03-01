// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {DISTRIBUTION} from "../types/ObjectType.sol";
import {IDistributionService} from "../instance/service/IDistributionService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {NftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {ReferralId} from "../types/Referral.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {Component} from "./Component.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

abstract contract Distribution is
    Component,
    IDistributionComponent
{
    using NftIdLib for NftId;

    bool internal _isVerifying;
    Fee internal _initialDistributionFee;

    TokenHandler internal _tokenHandler;

    IDistributionService private _distributionService;

    constructor(
        address registry,
        NftId instanceNftId,
        // TODO refactor into tokenNftId
        string memory name,
        address token,
        bool verifying,
        Fee memory distributionFee,
        address initialOwner,
        bytes memory data
    ) Component (
        registry, 
        instanceNftId, 
        name, token, 
        DISTRIBUTION(), 
        true, 
        initialOwner, 
        data
    ) {
        _isVerifying = verifying;
        _initialDistributionFee = distributionFee;

        _tokenHandler = new TokenHandler(token);
        _distributionService = getInstance().getDistributionService();

        _registerInterface(type(IDistributionComponent).interfaceId);
    }

    function setFees(
        Fee memory distributionFee
    )
        external
        override
        restricted()
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
        restricted()
        virtual override
    {
        // default is no action
    }

    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    )
        external
        restricted()
        virtual override
    {
        // default is no action
    }

    function referralIsValid(ReferralId referralId) external view returns (bool isValid) {
        // default is invalid
        return false;
    }

    function getSetupInfo() public view returns (ISetup.DistributionSetupInfo memory setupInfo) {
        InstanceReader reader = getInstance().getInstanceReader();
        setupInfo = reader.getDistributionSetupInfo(getNftId());

        // fallback to initial setup info (wallet is always != address(0))
        if(setupInfo.wallet == address(0)) {
            setupInfo = _getInitialSetupInfo();
        }
    }

    function _getInitialSetupInfo() internal view returns (ISetup.DistributionSetupInfo memory setupInfo) {
        return ISetup.DistributionSetupInfo(
            zeroNftId(),
            _tokenHandler,
            _initialDistributionFee,
            _isVerifying,
            address(this)
        );
    }
    

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying) {
        return _isVerifying;
    }
}
