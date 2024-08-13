// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {TokenHandler} from "./TokenHandler.sol";

library TokenHandlerDeployerLib {

    function deployTokenHandler(
        address registry,
        address component,
        address token, 
        address authority
    )
        public 
        returns (TokenHandler)
    {
        return new TokenHandler(registry, component, token, authority);
    }

}