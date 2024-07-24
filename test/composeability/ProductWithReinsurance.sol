// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../contracts/type/Amount.sol";
import {SimpleProduct} from "../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {ClaimId} from "../../contracts/type/ClaimId.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IOracleService} from "../../contracts/oracle/IOracleService.sol";
import {ORACLE} from "../../contracts/type/ObjectType.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {PayoutId} from "../../contracts/type/PayoutId.sol";
import {ReferralId} from "../../contracts/type/Referral.sol";
import {RequestId} from "../../contracts/type/RequestId.sol";
import {RiskId} from "../../contracts/type/RiskId.sol";
import {Seconds} from "../../contracts/type/Seconds.sol";
import {StateId} from "../../contracts/type/StateId.sol";
import {Timestamp, TimestampLib} from "../../contracts/type/Timestamp.sol";

uint64 constant SPECIAL_ROLE_INT = 11111;

contract ProductWithReinsurance is 
    SimpleProduct
{

    constructor(
        address registry,
        NftId instanceNftid,
        IAuthorization authorization,
        address initialOwner,
        address token,
        address pool,
        address distribution
    )
        SimpleProduct(
            registry,
            instanceNftid,
            authorization,
            initialOwner,
            token,
            false, // isInterceptor
            pool,
            distribution
        )
    {
    }
}