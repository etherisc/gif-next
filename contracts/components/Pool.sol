// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {POOL} from "../types/ObjectType.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {IBundleService} from "../instance/service/IBundleService.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {Fee, FeeLib} from "../types/Fee.sol";
import {UFixed} from "../types/UFixed.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {Component} from "./Component.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {ISetup} from "../instance/module/ISetup.sol";

import {IRegistry} from "../registry/IRegistry.sol";

import {ISetup} from "../instance/module/ISetup.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {Registerable} from "../shared/Registerable.sol";

abstract contract Pool is
    Component, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
        UFixed _collateralizationLevel;

        bool _isExternallyManaged;
        bool _isInterceptingBundleTransfers;
        bool _isVerifyingApplications;

        Fee _initialPoolFee;
        Fee _initialStakingFee;
        Fee _initialPerformanceFee;

        TokenHandler _tokenHandler;

        // may be used to interact with instance by derived contracts
        IPoolService _poolService;
        IBundleService _bundleService;
    }

    modifier onlyPoolService() {
        if(msg.sender != address(_getPoolStorage()._poolService)) {
            revert ErrorPoolNotPoolService(msg.sender);
        }
        _;
    }


    function _initializePool(
        address registry,
        NftId instanceNftId,
        string memory name,
        // TODO refactor into tokenNftId
        address token,
        UFixed collateralizationLevel,
        bool isInterceptingNftTransfers,
        bool isExternallyManaging,
        bool isVerifying,
        address initialOwner,
        bytes memory data
    )
        internal
        virtual
        onlyInitializing()
    {
        initializeComponent(registry, instanceNftId, name, token, POOL(), isInterceptingNftTransfers, initialOwner, data);

        PoolStorage storage $ = _getPoolStorage();

        $._isExternallyManaged = isExternallyManaging;
        $._isVerifyingApplications = isVerifying;

        // TODO add validation
        $._collateralizationLevel = collateralizationLevel;
        $._initialPoolFee = FeeLib.zeroFee();
        $._initialStakingFee = FeeLib.zeroFee();
        $._initialPerformanceFee = FeeLib.zeroFee();


        $._tokenHandler = new TokenHandler(token);

        $._poolService = getInstance().getPoolService();
        $._bundleService = getInstance().getBundleService();

        _registerInterface(type(IPoolComponent).interfaceId);
    }


    /**
     * @dev see {IPool.verifyApplication}. 
     * Default implementation that only writes a {LogUnderwrittenByPool} entry.
     */
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    )
        external
        onlyProductService
        virtual override 
    {
        require(
            policyMatchesBundle(applicationData, bundleFilter),
            "ERROR:POL-020:POLICY_BUNDLE_MISMATCH"
        );

        emit LogUnderwrittenByPool(applicationNftId, collateralizationAmount, address(this));
    }


    function isInterceptingBundleTransfers() external view override returns (bool) {
        return isNftInterceptor();
    }


    function isExternallyManaged() external view override returns (bool) {
        return _getPoolStorage()._isExternallyManaged;
    }


    function getCollateralizationLevel() external view override returns (UFixed collateralizationLevel) {
        return _getPoolStorage()._collateralizationLevel;
    }


    function isVerifyingApplications() external view override returns (bool isConfirmingApplication) {
        return _getPoolStorage()._isVerifyingApplications;
    }


    /// @dev see {IPoolComponent.policyMatchesBundle}. 
    /// Default implementation always returns true
    function policyMatchesBundle(
        bytes memory, // policyData
        bytes memory // bundleFilter
    )
        public
        pure
        virtual override
        returns (bool isMatching)
    {
        return true;
    }


    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        onlyOwner
        override
    {
        _getPoolStorage()._poolService.setFees(poolFee, stakingFee, performanceFee);
    }

    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        external
        override
        // TODO add onlyBundleOwner
    {
        _getPoolStorage()._bundleService.setBundleFee(bundleNftId, fee);
    }

    function lockBundle(
        NftId bundleNftId
    )
        external
        override
        // TODO add onlyBundleOwner
    {
        _getPoolStorage()._bundleService.lockBundle(bundleNftId);
    }

    function unlockBundle(
        NftId bundleNftId
    )
        external
        override
        // TODO add onlyBundleOwner
    {
        _getPoolStorage()._bundleService.unlockBundle(bundleNftId);
    }

    function getSetupInfo() public view returns (ISetup.PoolSetupInfo memory setupInfo) {
        InstanceReader reader = getInstance().getInstanceReader();
        setupInfo = reader.getPoolSetupInfo(getNftId());

        // fallback to initial setup info (wallet is always != address(0))
        if(setupInfo.wallet == address(0)) {
            setupInfo = _getInitialSetupInfo();
        }
    }

    function _getInitialSetupInfo() internal view returns (ISetup.PoolSetupInfo memory) {
        PoolStorage storage $ = _getPoolStorage();
        return ISetup.PoolSetupInfo(
            getProductNftId(),
            $._tokenHandler,
            $._collateralizationLevel,
            $._initialPoolFee,
            $._initialStakingFee,
            $._initialPerformanceFee,
            isNftInterceptor(),
            $._isVerifyingApplications,
            getWallet()
        );
    }

    // Internals

    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        uint256 amount,
        uint256 lifetime, 
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

    function getContractLocation(bytes memory name) external pure returns (bytes32 hash) {
        return keccak256(abi.encode(uint256(keccak256(name)) - 1)) & ~bytes32(uint256(0xff));
    }


    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
