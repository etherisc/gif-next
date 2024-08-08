// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../../type/Amount.sol";
import {BasicPool} from "../../pool/BasicPool.sol";
import {Fee} from "../../type/Fee.sol";
import {IAuthorization} from "../../authorization/IAuthorization.sol";
import {IComponents} from "../../instance/module/IComponents.sol";
import {NftId} from "../../type/NftId.sol";
import {Seconds} from "../../type/Timestamp.sol";
import {UFixed, UFixedLib} from "../../type/UFixed.sol";

contract FirePool is
    BasicPool
{
    
    constructor(
        address registry,
        NftId fireProductNftId,
        string memory componentName,
        address token,
        IAuthorization authorization
    ) 
    {
        address initialOwner = msg.sender;
        _intialize(
            registry,
            fireProductNftId,
            componentName,
            token,
            IComponents.PoolInfo({
                maxBalanceAmount: AmountLib.max(),
                isInterceptingBundleTransfers: false,
                isProcessingConfirmedClaims: false,
                isExternallyManaged: false,
                isVerifyingApplications: false,
                collateralizationLevel: UFixedLib.one(),
                retentionLevel: UFixedLib.one()
            }),
            authorization,
            initialOwner);
    }

    function _intialize(
        address registry,
        NftId fireProductNftId,
        string memory componentName,
        address token,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner
    )
        internal
        initializer
    {
        _initializeBasicPool(
            registry,
            instanceNftId,
            componentName,
            token,
            poolInfo,
            authorization,
            initialOwner);
    }

    function createBundle(
        Fee memory fee,
        Amount initialAmount,
        Seconds lifetime
    )
        external
        virtual 
        restricted()
        returns(NftId bundleNftId, Amount netStakedAmount)
    {
        address owner = msg.sender;
        bundleNftId = _createBundle(
            owner,
            fee,
            lifetime,
            "" // filter
        );
        netStakedAmount = _stake(bundleNftId, initialAmount);
    }

}