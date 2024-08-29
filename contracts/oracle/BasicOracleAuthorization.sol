// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../authorization/Authorization.sol";
import {BasicOracle} from "./BasicOracle.sol"; 
import {ORACLE} from "../type/ObjectType.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {IOracle} from "./IOracle.sol"; 
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RoleId} from "../type/RoleId.sol";


contract BasicOracleAuthorization
     is Authorization
{

     constructor(
          string memory componentName,
          string memory commitHash
     )
          Authorization(
               componentName, 
               ORACLE(), 
               3, 
               commitHash, 
               true, 
               false)
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          _authorizeServiceDomain(ORACLE(), address(15));
     }

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(ORACLE()));
          _authorize(functions, IOracle.request.selector, "request");
          _authorize(functions, IOracle.cancel.selector, "cancel");

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicOracle.respond.selector, "respond");
     }
}

