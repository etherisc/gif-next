// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../../registry/IRegistry.sol";

import {IProductService} from "../../service/IProductService.sol";
import {IPolicy, IPolicyModule} from "./IPolicy.sol";
import {ObjectType, POLICY} from "../../../types/ObjectType.sol";
import {APPLIED, ACTIVE, UNDERWRITTEN} from "../../../types/StateId.sol";
import {NftId, NftIdLib} from "../../../types/NftId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

abstract contract PolicyModule is IPolicyModule {
    using NftIdLib for NftId;

    mapping(NftId nftId => PolicyInfo info) private _policyInfo;

    // TODO find a better place to avoid dupliation
    modifier onlyProductService2() {
        require(
            msg.sender == address(this.getProductService()),
            "ERROR:POL-001:NOT_PRODUCT_SERVICE"
        );
        _;
    }

    function createApplication(
        NftId productNftId,
        NftId policyNftId,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        NftId bundleNftId
    )
        external
        onlyProductService2
        override
    {
        _policyInfo[policyNftId] = PolicyInfo(
            policyNftId,
            productNftId,
            bundleNftId,
            address(0), // beneficiary = policy nft holder
            // _lifecycleModule.getInitialState(POLICY()),
            APPLIED(),
            sumInsuredAmount,
            premiumAmount,
            0, // premium paid amount
            lifetime, 
            "", // data
            blockTimestamp(), // createdAt
            zeroTimestamp(), // activatedAt
            zeroTimestamp(), // expiredAt
            zeroTimestamp(), // closedAt
            blockNumber() // updatedIn
        );

        // TODO add logging
    }

    function setPolicyInfo(PolicyInfo memory policyInfo)
        external
        override
        onlyProductService2
    {
        _policyInfo[policyInfo.nftId] = policyInfo;
    }

    function getPolicyInfo(
        NftId nftId
    ) external view returns (PolicyInfo memory info) {
        return _policyInfo[nftId];
    }

}
