// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {IPolicy} from "../instance/module/IPolicy.sol";
import {IPolicyHolder} from "../shared/IPolicyHolder.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";

import {Amount} from "../type/Amount.sol";
import {APPLIED, COLLATERALIZED, KEEP_STATE, CLOSED, DECLINED, PAID} from "../type/StateId.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, COMPONENT, DISTRIBUTION, PRODUCT, POOL, POLICY, PRICE} from "../type/ObjectType.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Service} from "../shared/Service.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";


//    APPLIED  |                                            COLLATERALIZED                                         |   CLOSED
// ------------------------------------ now->> ---------- <<-activatedAt->> ---------- <<-expiredAt ---------- closedAt ------> timeline
//             |   AWAITING ACTIVATION   |    AWAITING  ACTIVE   |          ACTIVE           |    AWAITING CLOSE   |    
//             |                         |                adjustActivation()         adjustExpiration()            |
//       collateralize()              activate()                                                                 close()

// Can activate() if:
//    - AWAITING ACTIVATION
// activate():
//    - set initial activatedAt and expiredAt
//    - defines limits for adjustActivation(): now <= newActivatedAt < expiredAt 
//    - defines limits for adjustExpiration(): activatedAt < newExpiredAt < oldExpiredAt
// Can close() if:
//    - AWAITING ACTIVATION and premium is refunded? OR
//    - AWAITING CLOSE and no open claims OR
//    - total payouts amount == sum insured amount (forced close)
// close():
//    - free remaining collateral

// TODO if delta (expiredAt - activatedAt) is changed -> lifetime / collateralAmount / sumInsured MUST also change?
// TODO Use this lib in each contract where policyInfo.activatedAt, expiredAt, closedAt is checked
library PolicyLib
{
    error ErrorPolicyLibPolicyNotCollateralized(NftId policyNftId);
    error ErrorPolicyLibPolicyNotActivated(NftId policyNftId);
    error ErrorPolicyLibPolicyAlreadyActivated(NftId policyNftId);
    error ErrorPolicyLibPolicyActivationTooEarly(NftId policyNftId, Timestamp lowerLimit, Timestamp activateAt);
    error ErrorPolicyLibPolicyActivationTooLate(NftId policyNftId, Timestamp upperLimit, Timestamp activateAt);
    error ErrorPolicyLibPolicyNotActive(NftId policyNftId, StateId state);
    error ErrorPolicyLibPolicyExpired(NftId policyNftId);
    error ErrorPolicyLibPolicyExpirationTooLate(NftId policyNftId, Timestamp upperLimit, Timestamp requestedExpiredAt);
    error ErrorPolicyLibPolicyExpirationTooEarly(NftId policyNftId, Timestamp lowerLimit, Timestamp requestedExpiredAt);
    error ErrorPolicyLibPolicyNotCloseable(NftId policyNftId);

    function activate(
        InstanceReader reader,
        NftId policyNftId, 
        IPolicy.PolicyInfo memory info,
        Timestamp activateAt // initial activation time
    )
        external
        view 
        returns (IPolicy.PolicyInfo memory)
    {
        StateId state = reader.getPolicyState(policyNftId);

        // check policy can be activated
        {
            // is collateralized
            if(state != COLLATERALIZED()) {
                revert ErrorPolicyLibPolicyNotCollateralized(policyNftId);
            }

            // not activated yet
            if(info.activatedAt.gtz()) {
                revert ErrorPolicyLibPolicyAlreadyActivated(policyNftId);
            }
        }

        // check activation time >= "now"
        if(activateAt < TimestampLib.blockTimestamp()) {
            revert ErrorPolicyLibPolicyActivationTooEarly(policyNftId, TimestampLib.blockTimestamp(), activateAt);
        }

        // set inital activation time
        info.activatedAt = activateAt;
        // set initial expiration time
        info.expiredAt = activateAt.addSeconds(info.lifetime);

        return info;
    }

    // requires: now <= newActivatedAt < expiredAt
    function adjustActivation(
        InstanceReader reader,
        NftId policyNftId, 
        IPolicy.PolicyInfo memory info,
        Timestamp activateAt
    ) 
        external
        view 
        returns (IPolicy.PolicyInfo memory)
    {
        assert(info.expiredAt > info.activatedAt);
        StateId state = reader.getPolicyState(policyNftId);

        // check activation time can be adjusted
        {
            // is collateralized
            if(state != COLLATERALIZED()) {
                revert ErrorPolicyLibPolicyNotCollateralized(policyNftId);
            }
            
            // was activated
            if(info.activatedAt.eqz()) {
                revert ErrorPolicyLibPolicyNotActivated(policyNftId);
            }

            // not expired
            if(info.expiredAt < TimestampLib.blockTimestamp()) {
                revert ErrorPolicyLibPolicyExpired(policyNftId);
            }
        }

        // check new activation time is within limits
        // also checks for policy been expired -> if "now" >= info.expiredAt can not set any new value
        {
            if(activateAt < TimestampLib.blockTimestamp()) {
                revert ErrorPolicyLibPolicyActivationTooEarly(policyNftId, TimestampLib.blockTimestamp(), activateAt);
            }

            // TODO use (activateAt >= info.activatedAt) instead? -> can reduce activation time only?
            if(activateAt >= info.expiredAt) {
                revert ErrorPolicyLibPolicyActivationTooLate(policyNftId, info.expiredAt, activateAt);
            }
        }

        // TODO calculate new lifetime
        // set new activation time
        info.activatedAt = activateAt;

        return info;
    } 

    // Important: policy expiration is not a "state transition" but adjustment of expiredAt timestamp.
    // Thus this function can be called multiple times for the same policy, requires: now <= newExpiredAt < oldExpiredAt
    function adjustExpiration(
        InstanceReader reader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory info,
        Timestamp expireAt
    )
        external
        view
        returns (IPolicy.PolicyInfo memory)
    {
        assert(info.expiredAt > info.activatedAt);
        StateId state = reader.getPolicyState(policyNftId);

        // check expiredAt can be adjusted
        {
            // is collateralized
            if(state != COLLATERALIZED()) {
                revert ErrorPolicyLibPolicyNotCollateralized(policyNftId);
            }
            
            // was activated
            if(info.activatedAt.eqz()) {
                revert ErrorPolicyLibPolicyNotActivated(policyNftId);
            }

            // not expired
            if(info.expiredAt < TimestampLib.blockTimestamp()) {
                revert ErrorPolicyLibPolicyExpired(policyNftId);
            }
        }

        // update expireAt to current block timestamp if not set
        //if (expireAt.eqz()) {
        //    expireAt = TimestampLib.blockTimestamp();
        //}

        // check new expiration time is within limits
        // also checks for policy been expired -> if "now" >= info.expiredAt can not set any new value
        {
            if (expireAt <= info.activatedAt) {
                revert ErrorPolicyLibPolicyExpirationTooEarly(policyNftId, TimestampLib.blockTimestamp(), expireAt);
            }

            if (expireAt >= info.expiredAt) {
                revert ErrorPolicyLibPolicyExpirationTooLate(policyNftId, info.expiredAt, expireAt);
            }
        }

        // TODO calculate new lifetime
        // set new expiration time
        info.expiredAt = expireAt;

        return info;
    }

    function close(
        InstanceReader reader,
        NftId policyNftId,
        IPolicy.PolicyInfo memory info
    )
        external
        view
        returns (IPolicy.PolicyInfo memory)
    {
        StateId state = reader.getPolicyState(policyNftId);

        // check policy can be closed
        if (!isCloseable(state, info)) {
            revert ErrorPolicyLibPolicyNotCloseable(policyNftId);
        }

        // no update for expiredAt 
        // the only case when expiredAt is in the future:
        // sumInsured was fully payed out prior to expiration

        // set closed time
        info.closedAt = TimestampLib.blockTimestamp();

        return info;
    }

    function isCloseable(InstanceReader reader, NftId policyNftId)
        external
        view
        returns (bool)
    {
        StateId state = reader.getPolicyState(policyNftId);
        IPolicy.PolicyInfo memory info = reader.getPolicyInfo(policyNftId);

        return isCloseable(state, info);
    }

    /// @dev Returns true iff policy is closeable
    function isCloseable(
        StateId state,
        IPolicy.PolicyInfo memory info
    )
        public
        view
        returns (bool)
    {
        // not closeable: policy not collateralized
        if (state != COLLATERALIZED()) { return false; }

        // not closeable: policy don't exist
        if (info.productNftId.eqz()) { return false; }

        // not closeable: not activated yet
        if (info.activatedAt.eqz()) { return false; }

        // not closeable: activation timestamp is in the future
        if (info.activatedAt > TimestampLib.blockTimestamp()) { return false; } 

        // not closeable: has open claims
        if (info.openClaimsCount > 0) { return false; } 

        // closeable: if sum of claims matches sum insured a policy may be closed prior to the expiry date
        if (info.claimAmount == info.sumInsuredAmount) { return true; }

        // not closeable: not yet expired
        if (TimestampLib.blockTimestamp() < info.expiredAt) { return false; }

        // all conditions to close the policy are met
        return true; 
    }
}