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
    error ErrorTokenHandlerRecipientWalletsMustBeDistinct(address to, address to2, address to3);
    
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
    
    /// @dev collect tokens from outside of the gif and transfer them to one wallet within the scope of gif.
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function collectTokens(
        address from,
        address to,
        Amount amount
    )
        external
    {
        _transfer(from, to, amount);
    }

    /// @dev collect tokens from outside of the gif and transfer them to three distinct wallets within the scope of gif
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function collectTokens(
        address from,
        address to,
        Amount amount,
        address to2,
        Amount amount2,
        address to3,
        Amount amount3
    )
        external
    {
        if (to == to2 || to == to3 || to2 == to3) {
            revert ErrorTokenHandlerRecipientWalletsMustBeDistinct(to, to2, to3);
        }

        _checkPreconditons(from, amount + amount2 + amount3);

        if (amount.gtz()) {
            _transfer(from, to, amount);
        }
        if (amount2.gtz()) {
            _transfer(from, to2, amount2);
        }
        if (amount3.gtz()) {
            _transfer(from, to3, amount3);
        }
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
        // check amount and allowance
        _checkPreconditons(from, amount);

        // transfer the tokens
        emit LogTokenHandlerTokenTransfer(address(_token), from, to, amount.toInt());
        SafeERC20.safeTransferFrom(
            _token, 
            from, 
            to, 
            amount.toInt());
    }

    function _checkPreconditons(
        address from,
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
    }
}
