// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract ERC165 is IERC165 {
    mapping(bytes4 => bool) private _isSupported;

    constructor() {
        // register support for ERC165
        _registerInterface(type(IERC165).interfaceId);
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return _isSupported[interfaceId];
    }

    function _registerInterface(bytes4 interfaceId) internal {
        _isSupported[interfaceId] = true;
    }
}