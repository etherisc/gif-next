// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

// library 
library TokenTransferLib {

    error ErrorTokenTransferLibAmountIsZero();
    error ErrorTokenTransferLibAllowanceTooSmall(address from, address spender, uint256 allowance, uint256 amount);
    
    /// @dev collect tokens from outside of the gif and transfer them to a wallet within the scope of gif
    function collectTokens(
        address from,
        address to,
        Amount amount,
        TokenHandler tokenHandler
    )
        internal
    {

        if (amount.eqz()) {
            revert ErrorTokenTransferLibAmountIsZero();
        }

        uint256 allowance = tokenHandler.getToken().allowance(from, address(tokenHandler));
        if (allowance < amount.toInt()) {
            revert ErrorTokenTransferLibAllowanceTooSmall(from, address(tokenHandler), allowance, amount.toInt());
        }

        tokenHandler.transfer(
            from,
            to,
            amount);
    }

}
