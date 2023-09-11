// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IProductService} from "../product/IProductService.sol";
import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
import {ITreasuryModule} from "../treasury/ITreasury.sol";
import {IPoolModule} from "./IPoolModule.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

abstract contract PoolModule is IPoolModule {
    using NftIdLib for NftId;

    uint256 public constant INITIAL_CAPITAL = 10000 * 10 ** 6;
    uint256 public constant INITIAL_LOCKED_CAPITAL = 0;

    mapping(NftId nftId => PoolInfo info) private _poolInfo;

    IPolicyModule private _policyModule;
    ITreasuryModule private _treasuryModule;
    IProductService private _productService;

    modifier onlyProductService() {
        require(
            address(_productService) == msg.sender,
            "ERROR:POL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    constructor(address productService) {
        _policyModule = IPolicyModule(address(this));
        _treasuryModule = ITreasuryModule(address(this));
        _productService = IProductService(productService);
    }

    function registerPool(NftId nftId)
        public
        override
    {
        require(_poolInfo[nftId].nftId.eqz(), "ERROR:PL-001:ALREADY_CREATED");

        _poolInfo[nftId] = PoolInfo(
            nftId,
            INITIAL_CAPITAL,
            INITIAL_LOCKED_CAPITAL
        );
    }

    function underwrite(
        NftId policyNftId,
        NftId productNftId
    )
        external
        override
        onlyProductService
    {
        IPolicy.PolicyInfo memory policyInfo = _policyModule.getPolicyInfo(policyNftId);
        require(policyInfo.nftId == policyNftId, "ERROR:PL-002:POLICY_UNKNOWN");

        ITreasuryModule.ProductSetup memory product = _treasuryModule.getProductSetup(productNftId);
        require(product.productNftId == productNftId, "ERROR:PL-003:PRODUCT_SETUP_MISSING");

        NftId poolNftId = product.poolNftId;
        PoolInfo storage poolInfo = _poolInfo[poolNftId];
        require(poolInfo.nftId == poolNftId, "ERROR:PL-004:POOL_UNKNOWN");

        require(
            poolInfo.capital - poolInfo.lockedCapital >=
                policyInfo.sumInsuredAmount,
            "ERROR:PL-005:CAPACITY_TOO_LOW"
        );

        poolInfo.lockedCapital += policyInfo.sumInsuredAmount;
    }

    function getPoolInfo(
        NftId nftId
    ) external view override returns (PoolInfo memory info) {
        info = _poolInfo[nftId];
    }
}
