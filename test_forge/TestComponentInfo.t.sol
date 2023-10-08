// SPDX-License-Identifier: APACHE-2.0
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {console} from "../lib/forge-std/src/Script.sol";
import {TestGifBase} from "./base/TestGifBase.sol";
import {IComponent} from "../contracts/instance/module/component/IComponent.sol";
import {Key32} from "../contracts/types/Key32.sol";
import {NftId, NftIdLib} from "../contracts/types/NftId.sol";
import {COMPONENT, PRODUCT, POOL} from "../contracts/types/ObjectType.sol";
import {StateId, ACTIVE} from "../contracts/types/StateId.sol";

contract TestComponentInfo is TestGifBase {
    function testProductInfo() public {
        NftId productNftId = product.getNftId();
        Key32 key = productNftId.toKey32(COMPONENT());
        StateId productState = keyValueStore.getState(key);

        IERC20Metadata componentToken = instance.getComponentToken(productNftId);
        assertEq(address(componentToken), address(token), "unexpected token");

        // solhint-disable-next-line
        console.log("product (nftId, state)");
        // solhint-disable-next-line
        console.log(productNftId.toInt(), productState.toInt());

        assertEq(
            productState.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }

    function testPoolInfo() public {
        NftId poolNftId = pool.getNftId();
        Key32 key = poolNftId.toKey32(COMPONENT());
        StateId poolState = keyValueStore.getState(key);

        IERC20Metadata componentToken = instance.getComponentToken(poolNftId);
        assertEq(address(componentToken), address(token), "unexpected token");

        // solhint-disable-next-line
        console.log("pool (nftId, state)");
        // solhint-disable-next-line
        console.log(poolNftId.toInt(), poolState.toInt());

        assertEq(
            poolState.toInt(),
            ACTIVE().toInt(),
            "component state not active"
        );
    }
}
