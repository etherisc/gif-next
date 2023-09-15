// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistry, IRegistryLinked} from "../../../registry/IRegistry.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";
import {IPolicy, IPolicyModule} from "../../policy/IPolicy.sol";
import {ITreasuryModule} from "../../treasury/ITreasury.sol";
import {NftId, NftIdLib} from "../../../types/NftId.sol";

import {IPoolModule} from "./IPoolModule.sol";

abstract contract PoolModule is
    IPoolModule
{
    using NftIdLib for NftId;

    uint256 public constant INITIAL_CAPITAL = 10000 * 10 ** 6;
    uint256 public constant INITIAL_LOCKED_CAPITAL = 0;

    mapping(NftId nftId => PoolInfo info) private _poolInfo;

    IPolicyModule private _policyModule;
    ITreasuryModule private _treasuryModule;

    modifier onlyPoolProductService() {
        require(
            this.senderIsProductService(),
            "ERROR:PL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    constructor() {
        _policyModule = IPolicyModule(address(this));
        _treasuryModule = ITreasuryModule(address(this));
    }

    function registerPool(NftId nftId) public override {
        require(_poolInfo[nftId].nftId.eqz(), "ERROR:PL-010:ALREADY_CREATED");

        _poolInfo[nftId] = PoolInfo(
            nftId,
            INITIAL_CAPITAL,
            INITIAL_LOCKED_CAPITAL
        );
    }

    function underwrite(
        NftId policyNftId,
        NftId productNftId
    ) external override onlyPoolProductService {
        IPolicy.PolicyInfo memory policyInfo = _policyModule.getPolicyInfo(
            policyNftId
        );
        require(policyInfo.nftId == policyNftId, "ERROR:PL-002:POLICY_UNKNOWN");

        ITreasuryModule.ProductSetup memory product = _treasuryModule
            .getProductSetup(productNftId);
        require(
            product.productNftId == productNftId,
            "ERROR:PL-003:PRODUCT_SETUP_MISSING"
        );

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
