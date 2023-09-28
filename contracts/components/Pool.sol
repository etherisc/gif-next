// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType, POOL} from "../types/ObjectType.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IPoolService} from "../instance/service/IPoolService.sol";
import {NftId} from "../types/NftId.sol";
import {Fee} from "../types/Fee.sol";
import {UFixed} from "../types/UFixed.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {BaseComponent} from "./BaseComponent.sol";

contract Pool is BaseComponent, IPoolComponent {

    bool internal _isVerifying;
    UFixed internal _collateralizationLevel;

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
        // TODO refactor into tokenNftId
        address token,
        bool verifying,
        UFixed collateralizationLevel
    )
        BaseComponent(registry, instanceNftId, token)
    {
        _isVerifying = verifying;
        // TODO add validation
        _collateralizationLevel = collateralizationLevel;

        _poolService = _instance.getPoolService();
        _productService = _instance.getProductService();
    }

    function createBundle(
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
        uint256 amount,
        uint256 lifetime, 
        bytes calldata filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _poolService.createBundle(
            bundleOwner,
            amount,
            lifetime,
            filter
        );
    }

    // from pool component
    function getStakingFee()
        external
        view
        override
        returns (Fee memory stakingFee)
    {
        return _instance.getPoolSetup(getNftId()).stakingFee;
    }

    function getPerformanceFee()
        external
        view
        override
        returns (Fee memory performanceFee)
    {
        return _instance.getPoolSetup(getNftId()).performanceFee;
    }

    // from registerable
    function getType() public pure override returns (ObjectType) {
        return POOL();
    }
}
