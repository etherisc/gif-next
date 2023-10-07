// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {StateId, ACTIVE} from "../contracts/types/StateId.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestComponentInfo is TestGifBase {
    function testProductInfo() public {
        NftId productNftId = product.getNftId();
        StateId productState = instance.getComponentState(productNftId);

        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            productNftId
        );
        // solhint-disable-next-line
        console.log("product (nftId, state)");
        // solhint-disable-next-line
        console.log(productNftId.toInt(), productState.toInt());

        assertNftId(info.nftId, productNftId, "product nft mismatch");
        assertEq(
            productState.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }

    function testPoolInfo() public {
        NftId poolNftId = pool.getNftId();
        StateId poolState = instance.getComponentState(poolNftId);

        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            poolNftId
        );
        // solhint-disable-next-line
        console.log("pool (nftId, state)");
        // solhint-disable-next-line
        console.log(poolNftId.toInt(), poolState.toInt());

        assertNftId(info.nftId, pool.getNftId(), "pool nft mismatch");
        assertEq(
            poolState.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
