// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {TokenHandler} from "./TokenHandler.sol";

library TokenHandlerDeployerLib {

    function deployTokenHandler(address token, address authority, address initalAllowedWallet) public returns (TokenHandler) {
        return new TokenHandler(address(token), authority, initalAllowedWallet);
    }

}