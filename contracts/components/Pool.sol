// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Component} from "./Component.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {IBundleService} from "../instance/service/IBundleService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {POOL} from "../types/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../types/RoleId.sol";
import {Seconds} from "../types/Seconds.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../types/UFixed.sol";


abstract contract Pool is
    Component, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
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
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, POOL(), isInterceptingNftTransfers, initialOwner, registryData);

        PoolStorage storage $ = _getPoolStorage();
        $._poolService = getInstance().getPoolService();
        $._bundleService = getInstance().getBundleService();

        registerInterface(type(IPoolComponent).interfaceId);
    }


    function stake(
        NftId bundleNftId, 
        uint256 amount
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
        uint256 amount
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
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.lock(bundleNftId);
    }


    function unlockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.unlock(bundleNftId);
    }


    function close(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.close(bundleNftId);
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


    function setMaxCapitalAmount(uint256 maxCapitalAmount)
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
        _getPoolStorage()._poolService.setFees(poolFee, stakingFee, performanceFee);
    }


    /// @dev see {IPool.verifyApplication}
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        uint256 collateralizationAmount
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
        uint256 collateralizationAmount
    )
        public
        view
        virtual override
        returns (bool isMatching)
    {
        return true;
    }


    function getPoolInfo() external view returns (IComponents.PoolInfo memory poolInfo) {
        poolInfo = abi.decode(getComponentInfo().data, (IComponents.PoolInfo));
    }

    // Internals

    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        uint256 amount,
        Seconds lifetime, 
        bytes memory filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _getPoolStorage()._bundleService.create(
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

    /// @dev defines initial pool specification
    /// overwrite this function according to your use case
    function _getInitialInfo()
        internal
        view 
        virtual override
        returns (IComponents.ComponentInfo memory info)
    {
        return IComponents.ComponentInfo(
            getName(),
            getToken(),
            TokenHandler(address(0)), // will be created by GIF service during registration
            address(this), // contract is its own wallet
            abi.encode(
                IComponents.PoolInfo(
                    NftIdLib.zero(), // will be set when GIF registers the related product
                    PUBLIC_ROLE(), // bundleOwnerRole
                    type(uint256).max, // maxCapitalAmount,
                    isNftInterceptor(), // isInterceptingBundleTransfers
                    false, // isExternallyManaged,
                    false, // isVerifyingApplications,
                    UFixedLib.toUFixed(1), // collateralizationLevel,
                    UFixedLib.toUFixed(1), // retentionLevel,
                    FeeLib.zeroFee(), // initialPoolFee,
                    FeeLib.zeroFee(), // initialStakingFee,
                    FeeLib.zeroFee() // initialPerformanceFee,
                )));
    }


    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
