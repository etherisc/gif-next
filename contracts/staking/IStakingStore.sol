// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
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


interface IStakingStore {

    // event LogStakingStoreStakesIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    // event LogStakingStoreStakesDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    // event LogStakingStoreRewardsIncreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    // event LogStakingStoreRewardsDecreased(NftId nftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    // event LogStakingStoreRewardsRestaked(NftId nftId, Amount amount, Amount rewardAmount, Amount rewardIncrementAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    // // creating and updating of balance
    // error ErrorStakingStoreBalanceAlreadyInitialized(NftId nftId);
    // error ErrorStakingStoreBalanceNotInitialized(NftId nftId);

    //--- target specific functions ------------------------------------//

    function createTarget(
        NftId targetNftId,
        IStaking.TargetInfo memory targetInfo
    )
        external;


    function updateTarget(
        NftId targetNftId, 
        IStaking.TargetInfo memory targetInfo
    )
        external;

    //--- stake specific functions -------------------------------------//

    function create(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo,
        Amount stakeAmount
    )
        external;

    function update(
        NftId stakeNftId, 
        IStaking.StakeInfo memory stakeInfo
    )
        external;

    //--- general functions --------------------------------------------//


    function increaseBalance(NftId nftId, Amount amount, Amount rewardIncrementAmount)
        external;


    function restakeRewards(
        NftId nftId, 
        Amount rewardIncrementAmount
    )
        external;


    function updateRewards(
        NftId nftId, 
        Amount rewardIncrementAmount
    )
        external;


    function claimUpTo(
        NftId nftId, 
        Amount maxRewardAmount
    )
        external
        returns (Amount rewardsClaimedAmount);


    function unstakeUpTo(
        NftId nftId, 
        Amount maxUnstakeAmount,
        Amount maxClaimAmount
    )
        external
        returns (
            Amount unstakedAmount,
            Amount claimedAmount
        );

    //--- view functions -----------------------------------------------//

    function getTargetManager() external view returns (NftIdSetManager targetManager);

    function getStakeBalance(NftId nftId) external view returns (Amount balanceAmount);
    function getRewardBalance(NftId nftId) external view returns (Amount rewardAmount);
    function getBalanceUpdatedAt(NftId nftId) external view returns (Timestamp updatedAt);

    function getBalanceAndLastUpdatedAt(NftId nftId)
        external
        view
        returns (
            Amount stakeBalance,
            Timestamp lastUpdatedAt
        );
}
