// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {IPolicyHolder} from "./IPolicyHolder.sol";

library ContractLib {

    function isPolicyHolder(address target) external view returns (bool) {
        return ERC165Checker.supportsInterface(target, type(IPolicyHolder).interfaceId);
    }

    function isAccessManaged(address target) external view returns (bool) {
        if (!isContract(target)) {
            return false;
        }

        (bool success, ) = target.staticcall(
            abi.encodeWithSelector(
                IAccessManaged.authority.selector));

        return success;
    }

    function isContract(address target) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        return size > 0;
    }

    function supportsInterface(address target, bytes4 interfaceId)  external view returns (bool) {
        return ERC165Checker.supportsInterface(target, interfaceId);
    }
}