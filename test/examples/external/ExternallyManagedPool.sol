// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../../../contracts/type/Amount.sol";
import {BasicPoolAuthorization} from "../../../contracts/pool/BasicPoolAuthorization.sol";
import {ClaimId} from "../../../contracts/type/ClaimId.sol";
import {Fee, FeeLib} from "../../../contracts/type/Fee.sol";
import {IAuthorization} from "../../../contracts/authorization/IAuthorization.sol";
import {IComponents} from "../../../contracts/instance/module/IComponents.sol";
import {IPolicy} from "../../../contracts/instance/module/IPolicy.sol";
import {InstanceReader} from "../../../contracts/instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../../contracts/type/NftId.sol";
import {PayoutId} from "../../../contracts/type/PayoutId.sol";
import {PUBLIC_ROLE} from "../../../contracts/type/RoleId.sol";
import {ReferralLib} from "../../../contracts/type/Referral.sol";
import {RiskId, RiskIdLib} from "../../../contracts/type/RiskId.sol";
import {Seconds, SecondsLib} from "../../../contracts/type/Seconds.sol";
import {SimplePool} from "../../../contracts/examples/unpermissioned/SimplePool.sol";
import {SimpleProduct} from "../../../contracts/examples/unpermissioned/SimpleProduct.sol";
import {TimestampLib} from "../../../contracts/type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../../contracts/type/UFixed.sol";

contract ExternallyManagedPool is
    SimplePool
{

    NftId public bundleOneNftId;
    NftId public bundleTwoNftId;
    address public bundleOwner;

    constructor(
        address registry,
        NftId productNftId,
        IComponents.PoolInfo memory poolInfo,
        address initialOwner
    ) 
        SimplePool(
            registry,
            productNftId,
            poolInfo,
            new BasicPoolAuthorization("ExternallyManagedPool"),
            initialOwner
        )
    {
    }

    function init() public {
        _approveTokenHandler(
            getToken(), 
            AmountLib.max());
    }

    function createAndFundBundle(
        Amount amount
    )
        external 
        returns (NftId bundleNftId)
    {
        address bundleOwner = msg.sender;
        bundleNftId = _createBundle(
            bundleOwner, 
            FeeLib.zero(), 
            SecondsLib.toSeconds(10000), 
            "");

        _stake(
            bundleNftId, 
            amount);
    }
}