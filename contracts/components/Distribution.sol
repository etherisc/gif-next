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
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Distribution")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant DISTRIBUTION_STORAGE_LOCATION_V1 = 0xaab7c5ea03d290056d6c060e0833d3ebcbe647f7694616a2ec52738a64b2f900;

    struct DistributionStorage {
        Fee _initialDistributionFee;
        TokenHandler _tokenHandler;
        IDistributionService _distributionService;
    }


    function initializeDistribution(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        Fee memory distributionFee,
        address initialOwner,
        bytes memory data
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, DISTRIBUTION(), true, initialOwner, data);

        DistributionStorage storage $ = _getDistributionStorage();
        // TODO add validation
        $._initialDistributionFee = distributionFee;
        $._tokenHandler = new TokenHandler(token);
        $._distributionService = getInstance().getDistributionService();

        registerInterface(type(IDistributionComponent).interfaceId);
    }


    function setFees(
        Fee memory distributionFee
    )
        external
        override
    {
        _getDistributionStorage()._distributionService.setFees(distributionFee);
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
        InstanceReader reader = getInstance().getInstanceReader();
        setupInfo = reader.getDistributionSetupInfo(getNftId());

        // fallback to initial setup info (wallet is always != address(0))
        if(setupInfo.wallet == address(0)) {
            setupInfo = _getInitialSetupInfo();
        }
    }

    function _getInitialSetupInfo() internal view returns (ISetup.DistributionSetupInfo memory setupInfo) {
        DistributionStorage storage $ = _getDistributionStorage();
        return ISetup.DistributionSetupInfo(
            zeroNftId(),
            $._tokenHandler,
            $._initialDistributionFee,
            address(this)
        );
    }
    

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying) {
        return true;
    }

    function _getDistributionStorage() private pure returns (DistributionStorage storage $) {
        assembly {
            $.slot := DISTRIBUTION_STORAGE_LOCATION_V1
        }
    }
}
