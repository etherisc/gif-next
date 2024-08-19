// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../authorization/Authorization.sol";
import {BasicPool} from "./BasicPool.sol"; 
import {IAccess} from "../authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {POOL} from "../type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RoleId} from "../type/RoleId.sol";


contract BasicPoolAuthorization
     is Authorization
{

     constructor(string memory poolName)
          Authorization(poolName, POOL())
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          _addServiceTargetWithRole(POOL());
     }

     // TODO cleanup
     // function _setupTargets()
     //      internal
     //      virtual override
     // {
     //      _addComponentTargetWithRole(POOL()); // basic pool target
     // }


     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getMainTargetName(), PUBLIC_ROLE());
          _authorize(functions, BasicPool.stake.selector, "stake");
          _authorize(functions, BasicPool.unstake.selector, "unstake");
          _authorize(functions, BasicPool.extend.selector, "extend");
          _authorize(functions, BasicPool.lockBundle.selector, "lockBundle");
          _authorize(functions, BasicPool.unlockBundle.selector, "unlockBundle");
          _authorize(functions, BasicPool.closeBundle.selector, "closeBundle");
          _authorize(functions, BasicPool.setBundleFee.selector, "setBundleFee");

          _authorize(functions, BasicPool.setMaxBalanceAmount.selector, "setMaxBalanceAmount");
          _authorize(functions, BasicPool.setFees.selector, "setFees");
          _authorize(functions, BasicPool.stake.selector, "stake");
          _authorize(functions, BasicPool.unstake.selector, "unstake");
          _authorize(functions, BasicPool.extend.selector, "extend");

          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");

          _authorize(functions, BasicPool.withdrawBundleFees.selector, "withdrawBundleFees");

          // authorize pool service
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(POOL()));
          _authorize(functions, IPoolComponent.verifyApplication.selector, "verifyApplication");
     }
}

