// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Service} from "../../contracts/shared/Service.sol";
import {ObjectType, SERVICE} from "../../contracts/type/ObjectType.sol";

contract MockSizeService is Service {
    function _getDomain() internal pure override returns(ObjectType serviceDomain) {
        return SERVICE();
    }
}
