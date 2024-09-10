// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {Str} from "../type/String.sol";


interface IAuthorization is 
     IServiceAuthorization
{

     /// @dev Returns the token hander name.
     /// Only components have a token handler.
     function getTokenHandlerName() external view returns(string memory name);

     /// @dev Returns the token hander target.
     /// Only components have a token handler.
     function getTokenHandlerTarget() external view returns(Str target);

     /// @dev Returns the complete list of targets.
     function getTargets() external view returns(Str[] memory targets);

     /// @dev Returns true iff the specified target exists.
     function targetExists(Str target) external view returns(bool exists);
}

