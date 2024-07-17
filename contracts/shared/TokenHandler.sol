// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount} from "../type/Amount.sol";

/// @dev token specific transfer helper
/// a default token contract is provided via contract constructor
/// relies internally on oz SafeERC20.safeTransferFrom
contract TokenHandler is AccessManaged {
    error ErrorTokenHandlerAmountIsZero();
    error ErrorTokenHandlerBalanceTooLow(address token, address from, uint256 balance, uint256 expectedBalance);
    error ErrorTokenHandlerAllowanceTooSmall(address token, address from, address spender, uint256 allowance, uint256 expectedAllowance);
    error ErrorTokenHandlerRecipientWalletsMustBeDistinct(address to, address to2, address to3);
    
    event LogTokenHandlerTokenTransfer(address token, address from, address to, uint256 amountTransferred);

    IERC20Metadata private _token;

    constructor(address token, address initialAuthority) AccessManaged(initialAuthority) {
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
        restricted()
    {
        _transfer(from, to, amount);
    }

    /// @dev collect tokens from outside of the gif and transfer them to three distinct wallets within the scope of gif
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function collectTokensToThreeRecipients( 
        address from,
        address to,
        Amount amount,
        address to2,
        Amount amount2,
        address to3,
        Amount amount3
    )
        external
        restricted()
    {
        if (to == to2 || to == to3 || to2 == to3) {
            revert ErrorTokenHandlerRecipientWalletsMustBeDistinct(to, to2, to3);
        }

        _checkPreconditions(from, amount + amount2 + amount3);

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

    /// @dev distribute tokens from a wallet within the scope of gif to an external address.
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function distributeTokens(
        address from,
        address to,
        Amount amount
    )
        external
        restricted()
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
        // check amount > 0, balance >= amount and allowance >= amount
        _checkPreconditions(from, amount);

        // transfer the tokens
        emit LogTokenHandlerTokenTransfer(address(_token), from, to, amount.toInt());
        SafeERC20.safeTransferFrom(
            _token, 
            from, 
            to, 
            amount.toInt());
    }

    function _checkPreconditions(
        address from,
        Amount amount
    ) 
        internal
        view
    {
        // amount must be greater than zero
        if (amount.eqz()) {
            revert ErrorTokenHandlerAmountIsZero();
        }

        // balance must be >= amount
        uint256 balance = _token.balanceOf(from);
        if (balance < amount.toInt()) {
            revert ErrorTokenHandlerBalanceTooLow(address(_token), from, balance, amount.toInt());
        }

        // allowance must be >= amount
        uint256 allowance = _token.allowance(from, address(this));
        if (allowance < amount.toInt()) {
            revert ErrorTokenHandlerAllowanceTooSmall(address(_token), from, address(this), allowance, amount.toInt());
        }
    }
}
