// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {Fee, zeroFee} from "../../contracts/types/Fee.sol";
import {Pool} from "../../contracts/components/Pool.sol";


contract TestPool is Pool {

    constructor(address registry, address instance, address token)
        Pool(registry, instance, token)
    // solhint-disable-next-line no-empty-blocks
    {}

    function createBundle(
        uint256 amount,
        uint256 lifetime, 
        bytes calldata filter
    )
        external
        returns(NftId bundleNftId)
    {
        address bundleOwner = msg.sender;        
        return _createBundle(bundleOwner, amount, lifetime, filter);
    }
}