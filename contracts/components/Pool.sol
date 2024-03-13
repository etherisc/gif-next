// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Component} from "./Component.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {IBundleService} from "../instance/service/IBundleService.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {POOL} from "../types/ObjectType.sol";
import {RoleId, PUBLIC_ROLE} from "../types/RoleId.sol";
import {Seconds} from "../types/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed} from "../types/UFixed.sol";


abstract contract Pool is
    Component, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
        UFixed _collateralizationLevel;
        UFixed _retentionLevel;
        uint256 _maxCapitalAmount;
        
        bool _isExternallyManaged;
        bool _isVerifyingApplications;

        RoleId _bundleOwnerRole;
        bool _isInterceptingBundleTransfers;

        Fee _initialPoolFee;
        Fee _initialStakingFee;
        Fee _initialPerformanceFee;

        TokenHandler _tokenHandler;

        // may be used to interact with instance by derived contracts
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
        bool isExternallyManaging,
        bool isVerifying,
        UFixed collateralizationLevel,
        UFixed retentionLevel,
        address initialOwner,
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        public
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, POOL(), isInterceptingNftTransfers, initialOwner, registryData);

        PoolStorage storage $ = _getPoolStorage();
        // TODO add validation
        $._tokenHandler = new TokenHandler(token);
        $._maxCapitalAmount = type(uint256).max;
        $._isExternallyManaged = isExternallyManaging;
        $._isVerifyingApplications = isVerifying;
        $._bundleOwnerRole = PUBLIC_ROLE();
        $._collateralizationLevel = collateralizationLevel;
        $._retentionLevel = retentionLevel;
        $._initialPoolFee = FeeLib.zeroFee();
        $._initialStakingFee = FeeLib.zeroFee();
        $._initialPerformanceFee = FeeLib.zeroFee();
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
        _getPoolStorage()._bundleService.lockBundle(bundleNftId);
    }


    function unlockBundle(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        _getPoolStorage()._bundleService.unlockBundle(bundleNftId);
    }


    function close(NftId bundleNftId)
        public
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
    {
        // TODO add implementation
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
        _getPoolStorage()._bundleService.setBundleFee(bundleNftId, fee);
    }


    function setMaxCapitalAmount(uint256 maxCapitalAmount)
        public
        virtual
        restricted()
        onlyOwner()
    {
        // TODO refactor to use pool service
        // _getPoolStorage()._poolService.setMaxCapitalAmount(...);

        uint256 previousMaxCapitalAmount = _getPoolStorage()._maxCapitalAmount;
        _getPoolStorage()._maxCapitalAmount = maxCapitalAmount;

        emit LogPoolBundleMaxCapitalAmountUpdated(previousMaxCapitalAmount, maxCapitalAmount);
    }


    function setBundleOwnerRole(RoleId bundleOwnerRole)
        public
        virtual
        restricted()
        onlyOwner()
    {
        // TODO refactor to use pool service
        // _getPoolStorage()._poolService.setBundleOwnerRole(...);

        if(_getPoolStorage()._bundleOwnerRole != PUBLIC_ROLE()) {
            revert ErrorPoolBundleOwnerRoleAlreadySet();
        }

        _getPoolStorage()._bundleOwnerRole = bundleOwnerRole;

        emit LogPoolBundleOwnerRoleSet(bundleOwnerRole);
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
        // validate application data against bundle filter
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


    function getCollateralizationLevel() public view virtual returns (UFixed collateralizationLevel) {
        return _getPoolStorage()._collateralizationLevel;
    }


    function getRetentionLevel() public view virtual returns (UFixed retentionLevel) {
        return _getPoolStorage()._retentionLevel;
    }


    function isExternallyManaged() public view virtual returns (bool) {
        return _getPoolStorage()._isExternallyManaged;
    }


    function isVerifyingApplications() public view virtual returns (bool isConfirmingApplication) {
        return _getPoolStorage()._isVerifyingApplications;
    }


    function getMaxCapitalAmount() public view virtual returns (uint256 maxCapitalAmount) {
        return _getPoolStorage()._maxCapitalAmount;
    }


    function isInterceptingBundleTransfers() public view virtual returns (bool) {
        return isNftInterceptor();
    }


    function getBundleOwnerRole() public view returns (RoleId bundleOwnerRole) {
        return _getPoolStorage()._bundleOwnerRole;
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


    function getSetupInfo() public view returns (ISetup.PoolSetupInfo memory setupInfo) {
        InstanceReader reader = getInstance().getInstanceReader();
        setupInfo = reader.getPoolSetupInfo(getNftId());

        // fallback to initial setup info (wallet is always != address(0))
        if(setupInfo.wallet == address(0)) {
            setupInfo = _getInitialSetupInfo();
        }
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
        bundleNftId = _getPoolStorage()._bundleService.createBundle(
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


    function _getInitialSetupInfo() internal view returns (ISetup.PoolSetupInfo memory) {
        PoolStorage storage $ = _getPoolStorage();
        return ISetup.PoolSetupInfo(
            getProductNftId(),
            $._tokenHandler,
            $._maxCapitalAmount,
            isNftInterceptor(),
            $._isExternallyManaged,
            $._isVerifyingApplications,
            $._collateralizationLevel,
            $._retentionLevel,
            $._initialPoolFee,
            $._initialStakingFee,
            $._initialPerformanceFee,
            getWallet()
        );
    }


    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
