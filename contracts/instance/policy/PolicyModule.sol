// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


// import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";

import {IProductService} from "../product/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";


abstract contract PolicyModule is
    IRegistryLinked,
    IPolicyModule
{

    mapping(uint256 nftId => PolicyInfo info) private _policyInfo;
    mapping(uint256 nftId => uint256 bundleNftId) private _bundleForPolicy;

    IProductService private _productService;

    modifier onlyProductService() {
        require(address(_productService) == msg.sender, "ERROR:POL-001:NOT_PRODUCT_SERVICE");
        _;
    }

    constructor(address productService) {
        _productService = IProductService(productService);
    }


    function createApplication(
        IRegistry.RegistryInfo memory productInfo,
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        uint256 bundleNftId
    )
        external
        override
        onlyProductService
        returns(uint256 nftId)
    {
        // TODO add parameter validation
        if(bundleNftId > 0) {
            IRegistry.RegistryInfo memory bundleInfo = this.getRegistry().getInfo(bundleNftId);
            IRegistry.RegistryInfo memory poolInfo = this.getRegistry().getInfo(bundleInfo.parentNftId);
        }

        nftId = this.getRegistry().registerObjectForInstance(
            productInfo.nftId,
            this.getRegistry().POLICY(),
            applicationOwner);

        _policyInfo[nftId] = PolicyInfo(
            nftId,
            PolicyState.Applied,
            sumInsuredAmount,
            premiumAmount,
            lifetime,
            block.timestamp,
            0, // activatedAt
            0, // expiredAt
            0 // closedAt
        );

        _bundleForPolicy[nftId] = bundleNftId;

        // add logging
    }


    function getBundleNftForPolicy(uint256 nftId)
        external
        view
        returns(uint256 bundleNft)
    {
        return _bundleForPolicy[nftId];
    }


    function getPolicyInfo(uint256 nftId)
        external
        view
        returns(PolicyInfo memory info)
    {
        return _policyInfo[nftId];
    }
}
