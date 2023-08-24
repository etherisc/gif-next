// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IProductService} from "../product/IProductService.sol";
import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
import {IPoolModule} from "./IPoolModule.sol";

abstract contract PoolModule is
    IPoolModule
{
    uint256 public constant INITIAL_CAPITAL = 10000*10**6;

    mapping(uint256 nftId => PoolInfo info) private _poolInfo;

    IProductService private _productService;

    modifier onlyProductService() {
        require(address(_productService) == msg.sender, "ERROR:POL-001:NOT_PRODUCT_SERVICE");
        _;
    }

    constructor(address productService) {
        _productService = IProductService(productService);
    }

    function createPoolInfo(
        uint256 nftId,
        address wallet,
        address token
    )
        public
        override
    {
        require(
            _poolInfo[nftId].nftId == 0,
            "ERROR:PL-001:ALREADY_CREATED");

        _poolInfo[nftId] = PoolInfo(
            nftId,
            wallet,
            token,
            INITIAL_CAPITAL,
            0 // locked capital
        );

    }


    function underwrite(
        uint256 poolNftId,
        uint256 policyNftId
    )
        external
        override
        onlyProductService
    {
        PoolInfo storage poolInfo = _poolInfo[poolNftId];
        require(
            poolInfo.nftId == poolNftId,
            "ERROR:PL-002:POOL_UNKNOWN");

        IPolicyModule policyModule = IPolicyModule(address(this));
        IPolicy.PolicyInfo memory policyInfo = policyModule.getPolicyInfo(policyNftId);

        require(
            poolInfo.capital - poolInfo.lockedCapital >= policyInfo.sumInsuredAmount,
            "ERROR:PL-003:CAPACITY_TOO_LOW");

        poolInfo.lockedCapital += policyInfo.sumInsuredAmount;
    }


    function getPoolInfo(uint256 nftId)
        external
        view
        override
        returns(PoolInfo memory info)
    {
        info = _poolInfo[nftId];
    }

}