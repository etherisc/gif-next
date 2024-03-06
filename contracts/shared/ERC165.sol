// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

contract ERC165 is
    Initializable,
    IERC165
{
    mapping(bytes4 => bool) private _isSupported;

    // @dev register support for ERC165 itself
    function initializeERC165() public onlyInitializing() {
        _isSupported[type(IERC165).interfaceId] = true;
    }

    // @dev register support for provided interfaceId
    function registerInterface(bytes4 interfaceId) public onlyInitializing() {
        _isSupported[interfaceId] = true;
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return _isSupported[interfaceId];
    }
}