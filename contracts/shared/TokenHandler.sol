// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenHandler {
    IERC20Metadata private _token;

    constructor(address token) {
        _token = IERC20Metadata(token);
    }

    // TODO add logging
    function transfer(
        address from,
        address to,
        uint256 amount // TODO add authz (only treasury/instance/product/pool/ service)
    ) external {
        SafeERC20.safeTransferFrom(_token, from, to, amount);
        // _token.transferFrom(from, to, amount);
    }

    function getToken() external view returns (IERC20Metadata) {
        return _token;
    }
}
