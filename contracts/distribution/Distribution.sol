// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {DISTRIBUTION} from "../type/ObjectType.sol";
import {IDistributionService} from "./IDistributionService.sol";
import {IProductService} from "../product/IProductService.sol";
import {NftId, zeroNftId, NftIdLib, toNftId} from "../type/NftId.sol";
import {ReferralId, ReferralStatus, ReferralLib} from "../type/Referral.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {IDistribution} from "../instance/module/IDistribution.sol";
import {IDistributionComponent} from "./IDistributionComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";


abstract contract Distribution is
    InstanceLinkedComponent,
    IDistributionComponent
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Distribution")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant DISTRIBUTION_STORAGE_LOCATION_V1 = 0xaab7c5ea03d290056d6c060e0833d3ebcbe647f7694616a2ec52738a64b2f900;

    struct DistributionStorage {
        Fee _minDistributionOwnerFee;
        Fee _distributionFee;
        TokenHandler _tokenHandler;
        IDistributionService _distributionService;
        mapping(address distributor => NftId distributorNftId) _distributorNftId;
    }

    error ErrorDistributionAlreadyDistributor(address distributor, NftId distributorNftId);

    function initializeDistribution(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee,
        address initialOwner,
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, DISTRIBUTION(), true, initialOwner, registryData);

        DistributionStorage storage $ = _getDistributionStorage();
        // TODO add validation
        $._minDistributionOwnerFee = minDistributionOwnerFee;
        $._distributionFee = distributionFee;
        $._tokenHandler = new TokenHandler(token);
        $._distributionService = IDistributionService(_getServiceAddress(DISTRIBUTION())); 

        registerInterface(type(IDistributionComponent).interfaceId);
    }

    function setFees(
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee
    )
        external
        override
        onlyOwner
        restricted()
    {
        _getDistributionStorage()._distributionService.setFees(minDistributionOwnerFee, distributionFee);
    }

    function getDistributionFee() external view returns (Fee memory distributionFee) {
        DistributionStorage storage $ = _getDistributionStorage();
        return $._distributionFee;
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
        DistributionStorage storage $ = _getDistributionStorage();
        distributorType = $._distributionService.createDistributorType(
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
        DistributionStorage storage $ = _getDistributionStorage();
        if($._distributorNftId[distributor].gtz()) {
            revert ErrorDistributionAlreadyDistributor(distributor, $._distributorNftId[distributor]);
        }

        distributorNftId = $._distributionService.createDistributor(
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
        DistributionStorage storage $ = _getDistributionStorage();
        // TODO re-enable once implemented
        // $._distributionService.updateDistributorType(
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
        DistributionStorage storage $ = _getDistributionStorage();
        referralId = $._distributionService.createReferral(
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
        DistributionStorage storage $ = _getDistributionStorage();
        return $._distributorNftId[candidate].gtz();
    }

    function getDistributorNftId(address distributor)
        public
        view
        returns (NftId distributorNftId)
    {
        DistributionStorage storage $ = _getDistributionStorage();
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
            $._minDistributionOwnerFee,
            $._distributionFee,
            address(this),
            0
        );
    }


    function _nftTransferFrom(address from, address to, uint256 tokenId) internal virtual override {
        // keep track of distributor nft owner
        emit LogDistributorUpdated(to, msg.sender);
        DistributionStorage storage $ = _getDistributionStorage();
        $._distributorNftId[from] = zeroNftId();
        $._distributorNftId[to] = toNftId(tokenId);
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
