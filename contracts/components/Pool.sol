// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {NftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {UFixed} from "../types/UFixed.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {BaseComponent} from "./BaseComponent.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {ISetup} from "../instance/module/ISetup.sol";

import {IRegistry} from "../registry/IRegistry.sol";

// import {IPool} from "../instance/module/pool/IPoolModule.sol";
import {ITreasury} from "../instance/module/ITreasury.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {Registerable} from "../shared/Registerable.sol";

contract Pool is BaseComponent, IPoolComponent {
    using NftIdLib for NftId;

    bool internal _isVerifying;
    UFixed internal _collateralizationLevel;

    Fee internal _initialPoolFee;
    Fee internal _initialStakingFee;
    Fee internal _initialPerformanceFee;

    // may be used to interact with instance by derived contracts
    IPoolService internal _poolService;

    // only relevant to protect callback functions for "active" pools
    IProductService private _productService;

    modifier onlyPoolService() {
        require(
            msg.sender == address(_poolService), 
            "ERROR:POL-001:NOT_POOL_SERVICE");
        _;
    }

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
        bool isInterceptor,
        bool verifying,
        UFixed collateralizationLevel,
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee,
        address initialOwner
    )
        BaseComponent(registry, instanceNftId, productNftId, token, POOL(), isInterceptor, initialOwner)
    {
        _isVerifying = verifying;
        // TODO add validation
        _collateralizationLevel = collateralizationLevel;
        _initialPoolFee = poolFee;
        _initialStakingFee = stakingFee;
        _initialPerformanceFee = performanceFee;

        _poolService = _instance.getPoolService();
        _productService = _instance.getProductService();

        _registerInterface(type(IPoolComponent).interfaceId);
    }

    function createBundle(
        Fee memory fee,
        uint256 initialAmount,
        uint256 lifetime,
        bytes memory filter
    )
        external
        virtual override
        returns(NftId bundleNftId)
    {
        address owner = msg.sender;
        bundleNftId = _poolService.createBundle(
            owner,
            fee,
            initialAmount,
            lifetime,
            filter
        );

        // TODO add logging
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
        onlyProductService
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


    function isVerifying() external view override returns (bool verifying) {
        return _isVerifying;
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
        override
    {
        _poolService.setFees(poolFee, stakingFee, performanceFee);
    }

    function setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        external
        override
        // TODO add onlyBundleOwner
    {
        _poolService.setBundleFee(bundleNftId, fee);
    }

    function getSetupInfo() public view returns (ISetup.PoolSetupInfo memory setupInfo) {
        // TODO fix this
        if (getNftId().eq(zeroNftId())) {
            return ISetup.PoolSetupInfo(
                _productNftId,
                new TokenHandler(address(_token)),
                _collateralizationLevel,
                _initialPoolFee,
                _initialStakingFee,
                _initialPerformanceFee,
                _isVerifying,
                _wallet
            );
        } 

        InstanceReader reader = _instance.getInstanceReader();
        return reader.getPoolSetupInfo(getNftId());
    }

    // from IRegisterable

    // TODO used only once, occupies space
    // TODO do not use super
    function getInitialInfo() 
        public
        view
        override (IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory, bytes memory)
    {
        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = super.getInitialInfo();

        return (
            info,
            abi.encode(
                ISetup.PoolSetupInfo(
                    getProductNftId(),
                    new TokenHandler(address(getToken())),
                    _collateralizationLevel,
                    _initialPoolFee,
                    _initialStakingFee,
                    _initialPerformanceFee,
                    _isVerifying,
                    _wallet
                )
            )
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
        bundleNftId = _poolService.createBundle(
            bundleOwner,
            fee,
            amount,
            lifetime,
            filter
        );
    }
}
