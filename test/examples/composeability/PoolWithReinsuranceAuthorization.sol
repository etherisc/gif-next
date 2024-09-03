// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccess} from "../../../contracts/authorization/IAccess.sol";
import {IInstanceLinkedComponent} from "../../../contracts/shared/IInstanceLinkedComponent.sol";
import {IPolicyHolder} from "../../../contracts/shared/IPolicyHolder.sol";
import {IPoolComponent} from "../../../contracts/pool/IPoolComponent.sol";

import {Authorization} from "../../../contracts/authorization/Authorization.sol";
import {BasicPool} from "../../../contracts/pool/BasicPool.sol";
import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {CLAIM, POOL, POLICY} from "../../../contracts/type/ObjectType.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {RoleId} from "../../../contracts/type/RoleId.sol";


contract PoolWithReinsuranceAuthorization
     is BasicPoolAuthorization
{

     constructor()
          BasicPoolAuthorization("PoolWithReinsurance")
     {}

     function _setupServiceTargets()
          internal
          virtual override
     {
          super._setupServiceTargets();
          _authorizeServiceDomain(CLAIM(), address(14));
     }

     function _setupTargetAuthorizations()
          internal
          virtual override
     {
          super._setupTargetAuthorizations();

          // authorize claim service for callback
          IAccess.FunctionInfo[] storage functions;
          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(CLAIM()));
          _authorize(functions, IPoolComponent.processConfirmedClaim.selector, "processConfirmedClaim");

          functions = _authorizeForTarget(getMainTargetName(), getServiceRole(POOL()));
          _authorize(functions, IPolicyHolder.payoutExecuted.selector, "payoutExecuted");
     }
}

