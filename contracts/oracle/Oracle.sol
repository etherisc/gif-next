// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {COMPONENT, ORACLE} from "../type/ObjectType.sol";
import {IOracleService} from "./IOracleService.sol";
import {IProductService} from "../product/IProductService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../type/Referral.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IOracleComponent} from "./IOracleComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";


abstract contract Oracle is
    InstanceLinkedComponent,
    IOracleComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Distribution")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant DISTRIBUTION_STORAGE_LOCATION_V1 = 0xaab7c5ea03d290056d6c060e0833d3ebcbe647f7694616a2ec52738a64b2f900;

    struct OracleStorage {
        IComponentService _componentService;
        IOracleService _oracleService;
        mapping(address distributor => NftId distributorNftId) _distributorNftId;
    }

    error ErrorDistributionAlreadyDistributor(address distributor, NftId distributorNftId);

    function initializeDistribution(
        address registry,
        NftId instanceNftId,
        address initialOwner,
        string memory name,
        address token,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // component specifidc data 
    )
        public
        virtual
        onlyInitializing()
    {
        initializeInstanceLinkedComponent(registry, instanceNftId, name, token, ORACLE(), true, initialOwner, registryData, componentData);

        OracleStorage storage $ = _getOracleStorage();
        $._oracleService = IOracleService(_getServiceAddress(ORACLE())); 
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        registerInterface(type(IOracleComponent).interfaceId);
    }

    function register()
        external
        virtual
        onlyOwner()
    {
        _getOracleStorage()._componentService.registerOracle();
    }

    function setFees(
        Fee memory distributionFee,
        Fee memory minDistributionOwnerFee
    )
        external
        override
        onlyOwner()
        restricted()
    {
        _getOracleStorage()._componentService.setDistributionFees(
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
        public
        returns (DistributorType distributorType)
    {
        OracleStorage storage $ = _getOracleStorage();
        distributorType = $._oracleService.createDistributorType(
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
        public
        returns(NftId distributorNftId)
    {
        OracleStorage storage $ = _getOracleStorage();
        if($._distributorNftId[distributor].gtz()) {
            revert ErrorDistributionAlreadyDistributor(distributor, $._distributorNftId[distributor]);
        }

        distributorNftId = $._oracleService.createDistributor(
            distributor,
            distributorType,
            data);

        $._distributorNftId[distributor] = distributorNftId;
    }

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    )
        public
        // TODO figure out what we need for authz
        // and add it
    {
        OracleStorage storage $ = _getOracleStorage();
        // TODO re-enable once implemented
        // $._oracleService.updateDistributorType(
        //     distributorNftId,
        //     distributorType,
        //     data);
    }

    /**
     * @dev lets distributors create referral codes.
     * referral codes need to be unique
     */
    function _createReferral(
        NftId distributorNftId,
        string memory code,
        UFixed discountPercentage,
        uint32 maxReferrals,
        Timestamp expiryAt,
        bytes memory data
    )
        internal
        returns (ReferralId referralId)
    {
        OracleStorage storage $ = _getOracleStorage();
        referralId = $._oracleService.createReferral(
            distributorNftId,
            code,
            discountPercentage,
            maxReferrals,
            expiryAt,
            data);
    }

    function isDistributor(address candidate)
        public
        view
        returns (bool)
    {
        OracleStorage storage $ = _getOracleStorage();
        return $._distributorNftId[candidate].gtz();
    }

    function getDistributorNftId(address distributor)
        public
        view
        returns (NftId distributorNftId)
    {
        OracleStorage storage $ = _getOracleStorage();
        return $._distributorNftId[distributor];
    }

    function getDiscountPercentage(string memory referralCode)
        external
        view
        returns (
            UFixed discountPercentage, 
            ReferralStatus status
        )
    {
        ReferralId referralId = getReferralId(referralCode);
        return _getInstanceReader().getDiscountPercentage(referralId);
    }


    function getReferralId(
        string memory referralCode
    )
        public
        view 
        returns (ReferralId referralId)
    {
        return ReferralLib.toReferralId(
            getNftId(), 
            referralCode);      
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

    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    )
        external
        onlyOwner
        restricted()
        virtual override
    {
        // default is no action
    }
    

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external pure returns (bool verifying) {
        return true;
    }

    function _getOracleStorage() private pure returns (OracleStorage storage $) {
        assembly {
            $.slot := DISTRIBUTION_STORAGE_LOCATION_V1
        }
    }
}
