// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/module/treasury/ITreasury.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {NftId, NftIdLib} from "../../types/NftId.sol";
import {Fee, feeIsZero} from "../../types/Fee.sol";
import {Version, toVersion, toVersionPart} from "../../types/Version.sol";

import {ComponentServiceBase} from "./ComponentServiceBase.sol";
import {IPoolService} from "./IPoolService.sol";


contract PoolService is ComponentServiceBase, IPoolService {
    using NftIdLib for NftId;

    string public constant NAME = "PoolService";

    constructor(
        address registry,
        NftId registryNftId
    ) ComponentServiceBase(registry, registryNftId) // solhint-disable-next-line no-empty-blocks
    {
        _registerInterface(type(IPoolService).interfaceId);
    }

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return toVersion(
            toVersionPart(3),
            toVersionPart(0),
            toVersionPart(0));
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
    }

    function setFees(
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        override
    {
        (IRegistry.ObjectInfo memory info, IInstance instance) = _verifyAndGetPoolAndInstance();
        instance.setPoolFees(info.nftId, stakingFee, performanceFee);
    }

    function createBundle(
        address owner, 
        uint256 amount, 
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        override
        returns(NftId nftId)
    {
        (IRegistry.ObjectInfo memory poolInfo, IInstance instance) = _verifyAndGetPoolAndInstance();

        nftId = instance.createBundle(
            poolInfo,
            owner,
            amount,
            lifetime,
            filter
        );

        // add logging
    }
}
