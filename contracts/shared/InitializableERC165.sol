// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

contract InitializableERC165 is
    Initializable,
    IERC165
{
    mapping(bytes4 => bool) private _isSupported;

    // @dev initializes with support for ERC165
    function _initializeERC165() internal onlyInitializing() {
        _isSupported[type(IERC165).interfaceId] = true;
    }

    // @dev register support for provided interfaceId
    // includes initialization for ERC165_ID if not yet done
    function _registerInterface(bytes4 interfaceId) internal onlyInitializing() {
        _isSupported[interfaceId] = true;
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return _isSupported[interfaceId];
    }
}