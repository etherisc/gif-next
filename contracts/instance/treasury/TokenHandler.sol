// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenHandler {
    // TODO use oz safeTransferFrom

    IERC20 _token;

    constructor(address token) {
        _token = IERC20(token);
    }

    // TODO add logging
    function transfer(
        address from,
        address to,
        uint256 amount
    ) external // TODO add authz (only treasury)
    {
        _token.transferFrom(from, to, amount);
    }
}
