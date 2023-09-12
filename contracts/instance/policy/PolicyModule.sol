// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {IProductService} from "../product/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";
import {ObjectType, POLICY} from "../../types/ObjectType.sol";
import {ACTIVE} from "../../types/StateId.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";

abstract contract PolicyModule is
    IRegistryLinked,
    IPolicyModule
{
    using NftIdLib for NftId;

    mapping(NftId nftId => PolicyInfo info) private _policyInfo;
    mapping(NftId nftId => NftId bundleNftId) private _bundleForPolicy;

    LifecycleModule private _lifecycleModule;
    IProductService private _productService;

    // TODO find a better place to avoid dupliation
    modifier onlyProductService2() {
        require(
            address(_productService) == msg.sender,
            "ERROR:POL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    constructor(address productService) {
        _lifecycleModule = LifecycleModule(address(this));
        _productService = IProductService(productService);
    }

    function createApplication(
        IRegistry.RegistryInfo memory productInfo,
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    ) external override onlyProductService2 returns (NftId nftId) {
        // TODO add parameter validation
        if (bundleNftId.gtz()) {
            // IRegistry.RegistryInfo memory bundleInfo = this
            //     .getRegistry()
            //     .getInfo(bundleNftId);
            // IRegistry.RegistryInfo memory poolInfo = this.getRegistry().getInfo(bundleInfo.parentNftId);
        }

        nftId = this.getRegistry().registerObjectForInstance(
            productInfo.nftId,
            POLICY(),
            applicationOwner);

        _policyInfo[nftId] = PolicyInfo(
            nftId,
            _lifecycleModule.getInitialState(POLICY()),
            sumInsuredAmount,
            premiumAmount,
            0, // premium paid amount
            lifetime,
            // solhint-disable-next-line not-rely-on-time
            block.timestamp, // createdAt
            // solhint-disable-next-line not-rely-on-time
            block.timestamp, // updatedAt
            0, // activatedAt
            0, // expiredAt
            0 // closedAt
        );

        _bundleForPolicy[nftId] = bundleNftId;

        // add logging
    }

    function processPremium(NftId nftId) external override onlyProductService2 {
        PolicyInfo storage info = _policyInfo[nftId];
        info.premiumPaidAmount = info.premiumAmount;
        // solhint-disable-next-line not-rely-on-time
        info.updatedAt = block.timestamp;
    }


    function activate(NftId nftId) external override onlyProductService2 {
        PolicyInfo storage info = _policyInfo[nftId];
        // solhint-disable-next-line not-rely-on-time
        info.activatedAt = block.timestamp;
        // solhint-disable-next-line not-rely-on-time
        info.expiredAt = block.timestamp + info.lifetime;
        info.state = _lifecycleModule.checkAndLogTransition(nftId, POLICY(), info.state, ACTIVE());
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
}
