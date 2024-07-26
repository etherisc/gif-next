// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicProductAuthorization} from "../../../contracts/product/BasicProductAuthorization.sol";
import {console} from "../../../lib/forge-std/src/Script.sol";
import {GifTest} from "../../base/GifTest.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {ComponentService} from "../../../contracts/shared/ComponentService.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";

contract TestComponentService is GifTest {

    function test_componentServiceRegisterHappyCase() public {
        // TODO implement
    }
}
