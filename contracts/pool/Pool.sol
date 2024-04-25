// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {IBundleService} from "./IBundleService.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "./IPoolService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {BUNDLE, COMPONENT, POOL} from "../type/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";

abstract contract Pool is
    InstanceLinkedComponent, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
        IComponentService _componentService;
        IPoolService _poolService;
        IBundleService _bundleService;
    }


    modifier onlyBundleOwner(NftId bundleNftId) {
        if(msg.sender != getRegistry().ownerOf(bundleNftId)) {
            revert ErrorPoolNotBundleOwner(bundleNftId, msg.sender);
        }
        _;
    }


    modifier onlyPoolService() {
        if(msg.sender != address(_getPoolStorage()._poolService)) {
            revert ErrorPoolNotPoolService(msg.sender);
        }
        _;
    }


    function initializePool(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        bool isInterceptingNftTransfers,
        address initialOwner,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // component specifidc data 
    )
        public
        virtual
        onlyInitializing()
    {
        initializeInstanceLinkedComponent(registry, instanceNftId, name, token, POOL(), isInterceptingNftTransfers, initialOwner, registryData, componentData);

        PoolStorage storage $ = _getPoolStorage();
        $._poolService = IPoolService(_getServiceAddress(POOL())); 
        $._bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        registerInterface(type(IPoolComponent).interfaceId);
    }


    function register()
        external
        virtual
        onlyOwner()
    {
        _getPoolStorage()._componentService.registerPool();
    }


    function stake(
        NftId bundleNftId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        // TODO add implementation
    }


    function unstake(
        NftId bundleNftId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        // TODO add implementation
    }


    function extend(
        NftId bundleNftId, 
        Seconds lifetimeExtension
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        // TODO add implementation
    }


    function lockBundle(NftId bundleNftId)
        public
        virtual
        //restricted() // TODO consider adding this back
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.lock(bundleNftId);
    }


    function unlockBundle(NftId bundleNftId)
        public
        virtual
        //restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.unlock(bundleNftId);
    }


    function close(NftId bundleNftId)
        public
        virtual
        //restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._poolService.closeBundle(bundleNftId);
    }


    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.setFee(bundleNftId, fee);
    }


    function setMaxCapitalAmount(Amount maxCapitalAmount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _getPoolStorage()._poolService.setMaxCapitalAmount(maxCapitalAmount);
    }


    function setBundleOwnerRole(RoleId bundleOwnerRole)
        public
        virtual
        restricted()
        onlyOwner()
    {
        _getPoolStorage()._poolService.setBundleOwnerRole(bundleOwnerRole);
    }


    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        public
        virtual
        restricted()
        onlyOwner()
    {
        _getPoolStorage()._componentService.setPoolFees(poolFee, stakingFee, performanceFee);
    }


    /// @dev see {IPool.verifyApplication}
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    )
        public
        virtual
        restricted()
    {
        if(!applicationMatchesBundle(
            applicationNftId,
            applicationData, 
            bundleNftId, 
            bundleFilter,
            collateralizationAmount)
        )
        {
            revert ErrorPoolApplicationBundleMismatch(applicationNftId);
        }

        emit LogPoolVerifiedByPool(address(this), applicationNftId, collateralizationAmount);
    }


    /// @dev see {IPoolComponent.applicationMatchesBundle}
    /// Override this function to implement any custom application verification 
    /// Default implementation always returns true
    function applicationMatchesBundle(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    )
        public
        view
        virtual override
        returns (bool isMatching)
    {
        return true;
    }


    function getInitialPoolInfo()
        public 
        virtual 
        view 
        returns (IComponents.PoolInfo memory poolInfo)
    {
        return IComponents.PoolInfo(
            NftIdLib.zero(), // will be set when GIF registers the related product
            PUBLIC_ROLE(), // bundleOwnerRole
            AmountLib.max(), // maxCapitalAmount,
            isNftInterceptor(), // isInterceptingBundleTransfers
            false, // isExternallyManaged,
            false, // isVerifyingApplications,
            UFixedLib.toUFixed(1), // collateralizationLevel,
            UFixedLib.toUFixed(1), // retentionLevel,
            FeeLib.zero(), // initialPoolFee,
            FeeLib.zero(), // initialStakingFee,
            FeeLib.zero() // initialPerformanceFee,
        );
    }

    // Internals

    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        Amount amount,
        Seconds lifetime, 
        bytes memory filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _getPoolStorage()._poolService.createBundle(
            bundleOwner,
            fee,
            amount,
            lifetime,
            filter);

        // TODO add logging
    }

    // TODO remove function once this is no longer used to produce contract locations on the fly ...
    function getContractLocation(bytes memory name) external pure returns (bytes32 hash) {
        return keccak256(abi.encode(uint256(keccak256(name)) - 1)) & ~bytes32(uint256(0xff));
    }


    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
