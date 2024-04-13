// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../type/Amount.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IStakingService is IService
{
    /// @dev create a new stake with amount DIP to the specified target
    /// returns the id of the newly minted stake nft
    /// permissionless function
    function create(
        NftId targetNftId,
        Amount amount
    )
        external
        returns (
            NftId stakeNftId
        );

    /// @dev increase an existing stake by amount DIP
    /// updates the staking reward amount
    /// function restricted to the current stake owner
    function stake(
        NftId stakeNftId,
        Amount amount
    )
        external;

    /// @dev decrease an existing stake by amount DIP
    /// updates the staking reward amount
    /// function restricted to the current stake owner
    function unstake(
        NftId stakeNftId,
        Amount amount
    )
        external;

    /// @dev closes the specified stake
    /// all related stakes and all accumulated reward DIP are transferred to the current stake holder
    /// function restricted to the current stake owner
    function close(
        NftId stakeNftId
    )
        external;

    /// @dev re-stakes the current staked DIP as well as all accumulated rewards to the new stake target.
    /// all related stakes and all accumulated reward DIP are transferred to the current stake holder
    /// function restricted to the current stake owner
    function reStake(
        NftId stakeNftId,
        NftId newTargetNftId
    )
        external
        returns (
            NftId newStakeNftId,
            Timestamp unlockedAt
        );

    /// @dev increases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is collateralized
    /// function restricted to the pool service
    function increaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        returns (Amount totalValueLocked);


    /// @dev decreases the total value locked amount for the specified target by the provided token amount.
    /// function is called when a new policy is closed or payouts are executed
    /// function restricted to the pool service
    function decreaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        returns (Amount totalValueLocked);

    /// @dev sends total value locked data to the global staking contract.
    /// this is done via CCIP (cross chain communication) 
    function sendTotalValueLockedData(
        NftId targetNftId,
        address token
    )
        external;

    /// @dev receives total value locked data from a staking contract on a different chain.
    /// this is done via CCIP (cross chain communication) 
    function receiveTotalValueLockedData(
        NftId targetNftId,
        address token
    )
        external;
}