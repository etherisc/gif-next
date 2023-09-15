// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// import {IProduct} from "../../components/IProduct.sol";
// import {IOwnable, IRegistryLinked, IRegisterable, IRegistry} from "../../registry/IRegistry.sol";
// import {IInstance} from "../IInstance.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../../instance/IInstance.sol";
// import {IPolicy, IPolicyModule} from "../policy/IPolicy.sol";
// import {RegistryLinked} from "../../registry/Registry.sol";
// import {IProductService} from "./IProductService.sol";
import {ITreasury, ITreasuryModule, TokenHandler} from "../../instance/treasury/ITreasury.sol";
// import {IPoolModule} from "../../instance/pool/IPoolModule.sol";
// import {ObjectType, INSTANCE, PRODUCT} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {Fee, feeIsZero} from "../../types/Fee.sol";

import {ComponentService} from "./ComponentService.sol";
import {IPoolService} from "./IPoolService.sol";


contract PoolService is ComponentService, IPoolService {
    using NftIdLib for NftId;

    constructor(
        address registry
    ) ComponentService(registry) // solhint-disable-next-line no-empty-blocks
    {

    }

    function setFees(
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        external
        override
    {
        (IRegistry.RegistryInfo memory info, IInstance instance) = _verifyAndGetPoolAndInstance();
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
        (IRegistry.RegistryInfo memory poolInfo, IInstance instance) = _verifyAndGetPoolAndInstance();

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
