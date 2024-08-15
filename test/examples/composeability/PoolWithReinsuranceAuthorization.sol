// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Authorization} from "../../../contracts/authorization/Authorization.sol";
import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {IPolicyHolder} from "../../../contracts/shared/IPolicyHolder.sol";
import {BasicPool} from "../../../contracts/pool/BasicPool.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {IPoolComponent} from "../../../contracts/pool/IPoolComponent.sol";
import {CLAIM, POOL, POLICY} from "../../../contracts/type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";


contract PoolWithReinsuranceAuthorization
     is Authorization
{

     constructor()
          Authorization("PoolWithReinsurance")
     {}

     function _setupTargets()
          internal
          virtual override
     {
          uint64 index = 1; // 0 is default
          _addComponentTargetWithRole(POOL(), index);
     }


     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          IAccess.FunctionInfo[] storage functions;

          // authorize public role (open access to any account, only allows to lock target)
          functions = _authorizeForTarget(getTargetName(), PUBLIC_ROLE());
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
          _authorize(functions, BasicPool.withdrawBundleFees.selector, "withdrawBundleFees");
          _authorize(functions, SimplePool.approveTokenHandler.selector, "approveTokenHandler");
          _authorize(functions, IInstanceLinkedComponent.withdrawFees.selector, "withdrawFees");

          // authorize claim service for callback
          functions = _authorizeForTarget(getTargetName(), getServiceRole(CLAIM()));
          _authorize(functions, IPoolComponent.processConfirmedClaim.selector, "processConfirmedClaim");
          _authorize(functions, IPolicyHolder.payoutExecuted.selector, "payoutExecuted");
     }
}

