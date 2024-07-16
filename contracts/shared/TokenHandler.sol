// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount} from "../type/Amount.sol";

/// @dev token specific transfer helper
/// a default token contract is provided via contract constructor
/// relies internally on oz SafeERC20.safeTransferFrom
contract TokenHandler {
    error ErrorTokenHandlerAmountIsZero();
    error ErrorTokenHandlerAllowanceTooSmall(address from, address spender, uint256 allowance, uint256 amount);
    
    event LogTokenHandlerTokenTransfer(address token, address from, address to, uint256 amount);

    IERC20Metadata private _token;

    constructor(address token) {
        _token = IERC20Metadata(token);
    }

    /// @dev returns the default token defined for this TokenHandler
    function getToken()
        external
        view 
        returns (IERC20Metadata)
    {
        return _token;
    }
    
    /// @dev collect tokens from outside of the gif and transfer them to a wallet within the scope of gif
    function collectTokens(
        address from,
        address to,
        Amount amount
    )
        external
    {
        _transfer(from, to, amount);
    }

    /// @dev distribute tokens from a wallet within the scope of gif to an external address
    function distributeTokens(
        address from,
        address to,
        Amount amount
    )
        external
    {
        _transfer(from, to, amount);
    }

    function _transfer(
        address from,
        address to,
        Amount amount
    )
        internal
    {
        // check preconditions
        if (amount.eqz()) {
            revert ErrorTokenHandlerAmountIsZero();
        }

        uint256 allowance = _token.allowance(from, address(this));
        if (allowance < amount.toInt()) {
            revert ErrorTokenHandlerAllowanceTooSmall(from, address(this), allowance, amount.toInt());
        }

        // transfer the tokens
        emit LogTokenHandlerTokenTransfer(address(_token), from, to, amount.toInt());
        SafeERC20.safeTransferFrom(
            _token, 
            from, 
            to, 
            amount.toInt());
    }
}
