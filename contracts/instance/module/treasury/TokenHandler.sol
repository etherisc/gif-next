// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NftId} from "../../../types/NftId.sol";

contract TokenHandler {
    NftId private _productNftId;
    IERC20Metadata private _token;

    constructor(
        NftId productNftId,
        address token
    )
    {
        _productNftId = productNftId;
        _token = IERC20Metadata(token);
    }

    // TODO add logging
    function transfer(
        address from,
        address to,
        uint256 amount
    )
        external // TODO add authz (only treasury/instance/product/pool/ service)
    {
        // TODO switch to oz safeTransferFrom
        _token.transferFrom(from, to, amount);
    }

    function getProductNftId()
        external
        view
        returns(NftId)
    {
        return _productNftId;
    }

    function getToken()
        external
        view
        returns(IERC20Metadata)
    {
        return _token;
    }
}
