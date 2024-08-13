// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ComponentVerifyingService} from "../../contracts/shared/ComponentVerifyingService.sol";
import {ObjectType, COMPONENT} from "../../contracts/type/ObjectType.sol";

contract MockSizeComponentVerifyingService is ComponentVerifyingService {
    function _getDomain() internal virtual override pure returns (ObjectType) {
        return COMPONENT();
    }
}
