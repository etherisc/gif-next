// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IComponent} from "../shared/IComponent.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IStaking is 
    IComponent,
    IVersionable
{

    // info for individual stake
    struct StakeInfo {
        NftId nftId;
        NftId targetNftId;
        Amount stakeAmount;
        Amount rewardAmount;
        Timestamp lockedUntil;
    }

    struct InstanceTvlInfo {
        NftId instanceNftid;
        address token;
        Amount tvlAmount;
    }
}
