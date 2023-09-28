// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {ACTIVE} from "../contracts/types/StateId.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestComponentInfo is TestGifBase {
    function testProductInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            product.getNftId()
        );
        // solhint-disable-next-line
        console.log("product (nftId, state)");
        // solhint-disable-next-line
        console.log(info.nftId.toInt(), info.state.toInt());

        assertNftId(info.nftId, product.getNftId(), "product nft mismatch");
        assertEq(
            info.state.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }

    function testPoolInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            pool.getNftId()
        );
        // solhint-disable-next-line
        console.log("pool (nftId, state)");
        // solhint-disable-next-line
        console.log(info.nftId.toInt(), info.state.toInt());

        assertNftId(info.nftId, pool.getNftId(), "pool nft mismatch");
        assertEq(
            info.state.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
