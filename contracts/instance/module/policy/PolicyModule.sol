// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {LifecycleModule} from "../../module/lifecycle/LifecycleModule.sol";
import {IProductService} from "../../service/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";
import {ObjectType, POLICY} from "../../../types/ObjectType.sol";
import {ACTIVE} from "../../../types/StateId.sol";
import {NftId, zeroNftId, NftIdLib} from "../../../types/NftId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

import {LifecycleModule} from "../../module/lifecycle/LifecycleModule.sol";

abstract contract PolicyModule is IPolicyModule {
    using NftIdLib for NftId;

    mapping(NftId nftId => PolicyInfo info) private _policyInfo;
    mapping(NftId nftId => NftId bundleNftId) private _bundleForPolicy;

    LifecycleModule private _lifecycleModule;

    // TODO find a better place to avoid dupliation
    modifier onlyProductService2() {
        require(
            this.senderIsProductService(),
            "ERROR:POL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    constructor() {
        _lifecycleModule = LifecycleModule(address(this));
    }

    function createApplication(
        IRegistry.ObjectInfo memory productInfo,
        address initialOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external override onlyProductService2 returns (NftId nftId) {
        // TODO add parameter validation
        if (bundleNftId.gtz()) {
            // IRegistry.ObjectInfo memory bundleInfo = this
            //     .getRegistry()
            //     .getInfo(bundleNftId);
            // IRegistry.ObjectInfo memory poolInfo = this.getRegistry().getInfo(bundleInfo.parentNftId);
        }

        nftId = this.getRegistry().registerForInstance(
            IRegistry.ObjectInfo(
                zeroNftId(),
                productInfo.nftId,
                POLICY(),
                address(0), 
                initialOwner,
                ""            
            )
        );

        _policyInfo[nftId] = PolicyInfo(
            nftId,
            _lifecycleModule.getInitialState(POLICY()),
            sumInsuredAmount,
            premiumAmount,
            0, // premium paid amount
            lifetime, 
            blockTimestamp(), // createdAt
            zeroTimestamp(), // activatedAt
            zeroTimestamp(), // expiredAt
            zeroTimestamp(), // closedAt
            blockNumber() // updatedIn
        );

        _bundleForPolicy[nftId] = bundleNftId;

        // TODO add logging
    }

    function processPremium(NftId nftId, uint256 premiumAmount) external override onlyProductService2 {
        PolicyInfo storage info = _policyInfo[nftId];
        require(
            info.premiumPaidAmount + premiumAmount <= info.premiumAmount,
            "ERROR:POL-010:PREMIUM_AMOUNT_TOO_LARGE"
        );

        info.premiumPaidAmount += premiumAmount;

        info.updatedIn = blockNumber();
    }

    function activate(NftId nftId) external override onlyProductService2 {
        PolicyInfo storage info = _policyInfo[nftId];
        info.activatedAt = blockTimestamp();
        info.expiredAt = blockTimestamp().addSeconds(info.lifetime);
        info.state = _lifecycleModule.checkAndLogTransition(
            nftId,
            POLICY(),
            info.state,
            ACTIVE()
        );

        info.updatedIn = blockNumber();
    }

    function getBundleNftForPolicy(
        NftId nftId
    ) external view returns (NftId bundleNft) {
        return _bundleForPolicy[nftId];
    }

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info) {
        return _policyInfo[nftId];
    }

    function getPremiumAmount(NftId nftId) external view override returns(uint256 premiumAmount) {
        return _policyInfo[nftId].premiumAmount;
    }

}
