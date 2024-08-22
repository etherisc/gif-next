// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {NftId} from "../type/NftId.sol";
import {StateId, CLOSED, COLLATERALIZED} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";

library PolicyServiceLib {

    function checkExpiration(
        Timestamp newExpiredAt,
        NftId policyNftId,
        StateId policyState,
        IPolicy.PolicyInfo memory policyInfo
    )
        external 
        view
    {
        if (policyState != COLLATERALIZED()) { 
            revert IPolicyService.ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        } 
        if (TimestampLib.blockTimestamp() < policyInfo.activatedAt) { 
            revert IPolicyService.ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        } 

        // check expiredAt represents a valid expiry time
        if (newExpiredAt >= policyInfo.expiredAt) {
            revert IPolicyService.ErrorPolicyServicePolicyExpirationTooLate(policyNftId, policyInfo.expiredAt, newExpiredAt);
        }

        if (newExpiredAt.gtz() && newExpiredAt < TimestampLib.blockTimestamp()) {
            revert IPolicyService.ErrorPolicyServicePolicyExpirationTooEarly(policyNftId, TimestampLib.blockTimestamp(), newExpiredAt);
        }
    }

    function policyIsCloseable(InstanceReader instanceReader, NftId policyNftId)
        external 
        view
        returns (bool isCloseable)
    {
        // policy already closed
        if (instanceReader.getPolicyState(policyNftId) == CLOSED()) {
            return false;
        }

        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);
        
        if (info.productNftId.eqz()) { return false; } // not closeable: policy does not exist (or does not belong to this instance)
        if (info.activatedAt.eqz()) { return false; } // not closeable: not yet activated
        if (info.openClaimsCount > 0) { return false; } // not closeable: has open claims

        // closeable: if sum of claims matches sum insured a policy may be closed prior to the expiry date
        if (info.claimAmount == info.sumInsuredAmount) { return true; }

        // not closeable: not yet expired
        if (TimestampLib.blockTimestamp() < info.expiredAt) { return false; }

        // all conditions to close the policy are met
        return true; 
    }

}