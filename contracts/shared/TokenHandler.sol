// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount} from "../types/Amount.sol";

/// @dev token specific transfer helper
/// relies internally on oz SafeERC20.safeTransferFrom
contract TokenHandler {
    IERC20Metadata private _token;

    constructor(address token) {
        _token = IERC20Metadata(token);
    }

    function transfer(
        address from,
        address to,
        Amount amount
    )
        external
    {
        SafeERC20.safeTransferFrom(_token, from, to, amount.toInt());
    }

    function getToken()
        external
        view 
        returns (IERC20Metadata)
    {
        return _token;
    }
}
