// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../authorization/IAccess.sol";
import {IComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IPoolComponent} from "./IPoolComponent.sol";

import {Authorization} from "../authorization/Authorization.sol";
import {BasicPool} from "./BasicPool.sol"; 
import {COMPONENT, POOL} from "../type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../contracts/type/RoleId.sol";
import {RoleId} from "../type/RoleId.sol";
import {GIF_INITIAL_RELEASE} from "../registry/Registry.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPartLib} from "../type/Version.sol";

contract BasicPoolAuthorization
     is Authorization
{

     constructor(string memory poolName)
          Authorization(
               poolName, 
               POOL(), 
               GIF_INITIAL_RELEASE(),
               COMMIT_HASH,
               TargetType.Component, 
               true)
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          _authorizeServiceDomain(COMPONENT(), address(11));
          _authorizeServiceDomain(POOL(), address(12));
     }

     function _setupTokenHandlerAuthorizations() internal virtual override {
          // authorize token handler functions for component service role
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(COMPONENT()));
          _authorize(functions, TokenHandler.approve.selector, "approve");
          _authorize(functions, TokenHandler.setWallet.selector, "setWallet");
          _authorize(functions, TokenHandler.pushFeeToken.selector, "pushFeeToken");

          // authorize token handler functions for pool service role
          functions = _authorizeForTarget(getTokenHandlerName(), getServiceRole(POOL()));
          _authorize(functions, TokenHandler.pullToken.selector, "pullToken");
          _authorize(functions, TokenHandler.pushToken.selector, "pushToken");
     }

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
          _authorize(functions, BasicPool.setBundleLocked.selector, "setBundleLocked");
          _authorize(functions, BasicPool.closeBundle.selector, "closeBundle");
          _authorize(functions, BasicPool.setBundleFee.selector, "setBundleFee");

          _authorize(functions, BasicPool.setMaxBalanceAmount.selector, "setMaxBalanceAmount");
          _authorize(functions, BasicPool.setFees.selector, "setFees");
          _authorize(functions, BasicPool.stake.selector, "stake");
          _authorize(functions, BasicPool.unstake.selector, "unstake");
          _authorize(functions, BasicPool.extend.selector, "extend");

          _authorize(functions, IComponent.withdrawFees.selector, "withdrawFees");
          _authorize(functions, BasicPool.withdrawBundleFees.selector, "withdrawBundleFees");

          // authorize pool service
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(POOL()));
          _authorize(functions, IPoolComponent.verifyApplication.selector, "verifyApplication");
     }
}

