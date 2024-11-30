// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

contract InitializableERC165 is
    Initializable,
    IERC165
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.gif.InitializableERC165@3.0.0")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant INITIALIZABLE_ERC165_STORAGE_LOCATION_V3_0 = 0x2c5de3b4947d23a15785cdf804e1e581a3c5f54c0357f66e3f442def0f390100;

    struct InitializableERC165Storage {
        mapping(bytes4 => bool) _isSupported;
    }

    // @dev initializes with support for ERC165
    function __ERC165_init() internal onlyInitializing() {
        _initializeERC165();
    }

    function _initializeERC165() internal {
        InitializableERC165Storage storage $ = _getInitializableERC165Storage();
        $._isSupported[type(IERC165).interfaceId] = true;
    }

    // @dev register support for provided interfaceId
    // includes initialization for ERC165_ID if not yet done
    function _registerInterface(bytes4 interfaceId) internal onlyInitializing() {
        _registerInterfaceNotInitializing(interfaceId);
    }

    function _registerInterfaceNotInitializing(bytes4 interfaceId) internal{
        InitializableERC165Storage storage $ = _getInitializableERC165Storage();
        $._isSupported[interfaceId] = true;
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        InitializableERC165Storage storage $ = _getInitializableERC165Storage();
        return $._isSupported[interfaceId];
    }

    function _getInitializableERC165Storage() private pure returns (InitializableERC165Storage storage $) {
        assembly {
            $.slot := INITIALIZABLE_ERC165_STORAGE_LOCATION_V3_0
        }
    }
}