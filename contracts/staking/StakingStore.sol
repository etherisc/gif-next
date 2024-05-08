// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {Component} from "../shared/Component.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {Key32} from "../type/Key32.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {KEEP_STATE} from "../type/StateId.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {NftIdSetManager} from "../shared/NftIdSetManager.sol";
import {ObjectType, INSTANCE, PROTOCOL, STAKE, STAKING, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";
import {TokenRegistry} from "../registry/TokenRegistry.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";
import {Version, VersionLib} from "../type/Version.sol";
import {Versionable} from "../shared/Versionable.sol";


contract StakingStore is 
    AccessManaged,
    KeyValueStore
{

    IRegistry private _registry;
    NftIdSetManager private _targetManager;
    StakingReader private _reader;

    constructor(
        address initialAuthority,
        address registryAddress,
        address stakingReaderAddress
    )
        AccessManaged(initialAuthority)
    {
        _registry = IRegistry(registryAddress);
        _reader = StakingReader(stakingReaderAddress);
        _targetManager = new NftIdSetManager();
        _targetManager.setOwner(address(this));
    }

    //--- target specific functions ------------------------------------//

    function createTarget(
        NftId targetNftId,
        IStaking.TargetInfo memory targetInfo
    )
        external
    {
        _create(
            targetNftId.toKey32(TARGET()),
            abi.encode(targetInfo));

        _targetManager.add(targetNftId);
    }


    function updateTarget(
        NftId targetNftId, 
        IStaking.TargetInfo memory targetInfo
    )
        external
    {
        _update(
            targetNftId.toKey32(TARGET()), 
            abi.encode(targetInfo), KEEP_STATE());
    }

    //--- stake specific functions -------------------------------------//

    function create(
        NftId stakeNftId, 
        NftId targetNftId, 
        Amount dipAmount
    )
        external
    {
        Timestamp currentTime = TimestampLib.blockTimestamp();
        Timestamp lockedUntil = currentTime.addSeconds(
            _reader.getTargetInfo(targetNftId).lockingPeriod);

        _create(
            stakeNftId.toKey32(STAKE()),
            abi.encode(
                IStaking.StakeInfo({
                    stakeAmount: dipAmount,
                    rewardAmount: AmountLib.zero(),
                    lockedUntil: lockedUntil,
                    rewardsUpdatedAt: currentTime
                })));
    }

    //--- view functions -----------------------------------------------//


    function getTargetManager() external view returns (NftIdSetManager targetManager){
        return _targetManager;
    }
}
