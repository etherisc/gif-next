// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./TestGifBase.sol";
import {IComponent} from "../contracts/instance/component/IComponent.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";

contract TestComponentInfo is TestGifBase {


    function testProductInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(product.getNftId());
        console.log("product (nftId, state)");
        console.log(NftIdLib.toInt(info.nftId), uint(info.state));

        assertNftId(info.nftId, product.getNftId(), "product nft mismatch");
        assertEq(uint256(info.state), uint256(IComponent.CState.Active), "component state not active");
    }

    function testPoolInfo() public {
        IComponent.ComponentInfo memory info = instance.getComponentInfo(pool.getNftId());
        console.log("pool (nftId, state)");
        console.log(NftIdLib.toInt(info.nftId), uint(info.state));

        assertNftId(info.nftId, pool.getNftId(), "pool nft mismatch");
        assertEq(uint256(info.state), uint256(IComponent.CState.Active), "component state not active");
    }
}
