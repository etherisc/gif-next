// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount} from "../type/Amount.sol";

/// @dev token specific transfer helper
/// a default token contract is provided via contract constructor
/// relies internally on oz SafeERC20.safeTransferFrom
contract TokenHandler {
    IERC20Metadata private _token;

    constructor(address token) {
        _token = IERC20Metadata(token);
    }

    /// @dev transfer amount default tokens 
    function transfer(
        address from,
        address to,
        Amount amount
    )
        external
    {
        SafeERC20.safeTransferFrom(
            _token, 
            from, 
            to, 
            amount.toInt());
    }

    /// @dev transfer amount of the specified token
    function safeTransferFrom(
        address token,
        address from,
        address to,
        Amount amount
    )
        external
    {
        SafeERC20.safeTransferFrom(
            IERC20Metadata(token), 
            from, 
            to, 
            amount.toInt());
    }

    /// @dev returns the default token defined for this TokenHandler
    function getToken()
        external
        view 
        returns (IERC20Metadata)
    {
        return _token;
    }
}
