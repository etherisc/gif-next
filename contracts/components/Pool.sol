// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {POOL} from "../types/ObjectType.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {IBundleService} from "../instance/service/IBundleService.sol";
import {NftId, NftIdLib} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {UFixed} from "../types/UFixed.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {Component} from "./Component.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {ISetup} from "../instance/module/ISetup.sol";

import {ISetup} from "../instance/module/ISetup.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";


abstract contract Pool is Component, IPoolComponent {
    using NftIdLib for NftId;

    bool internal _isConfirmingApplication;
    UFixed internal _collateralizationLevel;

    Fee internal _initialPoolFee;
    Fee internal _initialStakingFee;
    Fee internal _initialPerformanceFee;

    TokenHandler internal _tokenHandler;

    // may be used to interact with instance by derived contracts
    IPoolService internal _poolService;
    IBundleService private _bundleService;

    modifier onlyPoolService() {
        require(
            msg.sender == address(_poolService), 
            "ERROR:POL-001:NOT_POOL_SERVICE");
        _;
    }

    constructor(
        address registry,
        NftId instanceNftId,
        string memory name,
        // TODO refactor into tokenNftId
        address token,
        bool isInterceptor,
        bool isConfirmingApplication,
        UFixed collateralizationLevel,
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee,
        address initialOwner,
        bytes memory data
    ) Component(
        registry, 
        instanceNftId, 
        name, 
        token, 
        POOL(), 
        isInterceptor, 
        initialOwner, 
        data
    ) {
        _isConfirmingApplication = isConfirmingApplication;
        // TODO add validation
        _collateralizationLevel = collateralizationLevel;
        _initialPoolFee = poolFee;
        _initialStakingFee = stakingFee;
        _initialPerformanceFee = performanceFee;

        _tokenHandler = new TokenHandler(token);

        _poolService = getInstance().getPoolService();
        _bundleService = getInstance().getBundleService();

        _registerInterface(type(IPoolComponent).interfaceId);
    }

    /**
     * @dev see {IPool.underwrite}. 
     * Default implementation that only writes a {LogUnderwrittenByPool} entry.
     */
    function underwrite(
        NftId policyNftId, 
        bytes memory policyData,
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    )
        external
        restricted()
        virtual override 
    {
        _underwrite(policyNftId, policyData, bundleFilter, collateralizationAmount);
    }

    /**
     * @dev see {IPoolComponent.policyMatchesBundle}. 
     * Default implementation always returns true
     */
    function policyMatchesBundle(
        bytes memory, // policyData
        bytes memory // bundleFilter
    )
        public
        view
        virtual override
        returns (bool isMatching)
    {
        return true;
    }


    function isConfirmingApplication() external view override returns (bool isConfirmingApplication) {
        return _isConfirmingApplication;
    }

    function getCollateralizationLevel() external view override returns (UFixed collateralizationLevel) {
        return _collateralizationLevel;
    }

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        onlyOwner
        restricted()
        override
    {
        _poolService.setFees(poolFee, stakingFee, performanceFee);
    }

    function _setBundleFee(NftId bundleNftId, Fee memory fee) internal {
        _bundleService.setBundleFee(bundleNftId, fee);
    }

    function _lockBundle(NftId bundleNftId) internal {
        _bundleService.lockBundle(bundleNftId);
    }

    function _unlockBundle(NftId bundleNftId) internal {
        _bundleService.unlockBundle(bundleNftId);
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
        return ISetup.PoolSetupInfo(
            getProductNftId(),
            _tokenHandler,
            _collateralizationLevel,
            _initialPoolFee,
            _initialStakingFee,
            _initialPerformanceFee,
            false,
            _isConfirmingApplication,
            getWallet()
        );
    }

    // Internals

    function _underwrite(
        NftId policyNftId, 
        bytes memory policyData,
        bytes memory bundleFilter,
        uint256 collateralizationAmount
    )
        internal 
    {
        require(
            policyMatchesBundle(policyData, bundleFilter),
            "ERROR:POL-020:POLICY_BUNDLE_MISMATCH"
        );

        emit LogUnderwrittenByPool(policyNftId, collateralizationAmount, address(this));
    }

    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        uint256 amount,
        uint256 lifetime, 
        bytes calldata filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _bundleService.createBundle(
            bundleOwner,
            fee,
            amount,
            lifetime,
            filter
        );
    }
}
