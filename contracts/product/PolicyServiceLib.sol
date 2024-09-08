// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {InstanceReader} from "../instance/InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyService} from "../product/IPolicyService.sol";
import {NftId} from "../type/NftId.sol";
import {StateId, CLOSED, COLLATERALIZED} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";

library PolicyServiceLib {

    function policyIsActive(InstanceReader instanceReader, NftId policyNftId)
        external 
        view
        returns (bool isActive)
    {
        // policy not collateralized
        if (instanceReader.getPolicyState(policyNftId) != COLLATERALIZED()) {
            return false;
        }

        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);

        if (info.productNftId.eqz()) { return false; } // not closeable: policy does not exist (or does not belong to this instance)
        if (info.activatedAt.eqz()) { return false; } // not closeable: not yet activated
        if (info.activatedAt > TimestampLib.current()) { return false; } // not yet active
        if (info.expiredAt <= TimestampLib.current()) { return false; } // already expired

        return true;
    }

    function activate(
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo,
        Timestamp activateAt
    )
        external
        pure 
        returns (IPolicy.PolicyInfo memory)
    {
        // fail if policy has already been activated and activateAt is different
        if(! policyInfo.activatedAt.eqz() && activateAt != policyInfo.activatedAt) {
            revert IPolicyService.ErrorPolicyServicePolicyAlreadyActivated(policyNftId);
        }

        // ignore if policy has already been activated and activateAt is the same
        if (policyInfo.activatedAt == activateAt) {
            return policyInfo;
        }

        policyInfo.activatedAt = activateAt;
        policyInfo.expiredAt = activateAt.addSeconds(policyInfo.lifetime);

        return policyInfo;
    }

    function expire(
        InstanceReader instanceReader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory policyInfo,
        Timestamp expireAt
    )
        external
        view
        returns (IPolicy.PolicyInfo memory)
    {
        StateId policyState = instanceReader.getPolicyState(policyNftId);

        checkExpiration(
            expireAt,
            policyNftId,
            policyState,
            policyInfo);

        // effects
        // update policyInfo with new expiredAt timestamp
        if (expireAt.gtz()) {
            policyInfo.expiredAt = expireAt;
        } else {
            policyInfo.expiredAt = TimestampLib.current();
        }

        return policyInfo;
    }

    function checkExpiration(
        Timestamp newExpiredAt,
        NftId policyNftId,
        StateId policyState,
        IPolicy.PolicyInfo memory policyInfo
    )
        public 
        view
    {
        if (policyState != COLLATERALIZED()) { 
            revert IPolicyService.ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        } 
        if (TimestampLib.current() < policyInfo.activatedAt) { 
            revert IPolicyService.ErrorPolicyServicePolicyNotActive(policyNftId, policyState);
        } 

        // check expiredAt represents a valid expiry time
        if (newExpiredAt >= policyInfo.expiredAt) {
            revert IPolicyService.ErrorPolicyServicePolicyExpirationTooLate(policyNftId, policyInfo.expiredAt, newExpiredAt);
        }

        if (newExpiredAt.gtz() && newExpiredAt < TimestampLib.current()) {
            revert IPolicyService.ErrorPolicyServicePolicyExpirationTooEarly(policyNftId, TimestampLib.current(), newExpiredAt);
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
        if (TimestampLib.current() < info.expiredAt) { return false; }

        // all conditions to close the policy are met
        return true; 
    }

}