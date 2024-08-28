// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Component} from "../shared/Component.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, PROTOCOL, TARGET} from "../type/ObjectType.sol";
import {Seconds, SecondsLib} from "../type/Seconds.sol";
import {StakingReader} from "./StakingReader.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


library TargetManagerLib {

    function updateLockingPeriod(
        IStaking staking,
        NftId targetNftId, 
        Seconds lockingPeriod
    )
        external
        view
        returns (
            Seconds oldLockingPeriod,
            IStaking.TargetInfo memory targetInfo
        )
    {
        StakingReader reader = staking.getStakingReader();

        // check target exists
        if(!reader.isTarget(targetNftId)) {
            revert IStaking.ErrorStakingTargetNotFound(targetNftId);
        }

        checkLockingPeriod(targetNftId, lockingPeriod);

        targetInfo = reader.getTargetInfo(targetNftId);
        oldLockingPeriod = targetInfo.lockingPeriod;

        targetInfo.lockingPeriod = lockingPeriod;
    }


    function updateRewardRate(
        IStaking staking,
        NftId targetNftId, 
        UFixed rewardRate
    )
        external
        view
        returns (
            UFixed oldRewardRate,
            IStaking.TargetInfo memory targetInfo
        )
    {
        StakingReader reader = staking.getStakingReader();

        // check target exists
        if(!reader.isTarget(targetNftId)) {
            revert IStaking.ErrorStakingTargetNotFound(targetNftId);
        }

        checkRewardRate(targetNftId, rewardRate);

        targetInfo = reader.getTargetInfo(targetNftId);
        oldRewardRate = targetInfo.rewardRate;

        targetInfo.rewardRate = rewardRate;
    }


    function checkTargetParameters(
        IRegistry registry,
        StakingReader stakingReader,
        NftId targetNftId,
        ObjectType expectedObjectType,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    )
        external
        view
    {
        // target nft id must not be zero
        if (targetNftId.eqz()) {
            revert IStaking.ErrorStakingTargetNftIdZero();
        }

        // only accept "new" targets to be registered
        if (stakingReader.isTarget(targetNftId)) {
            revert IStaking.ErrorStakingTargetAlreadyRegistered(targetNftId);
        }

        // target object type must be allowed
        if (!isTargetTypeSupported(expectedObjectType)) {
            revert IStaking.ErrorStakingTargetTypeNotSupported(targetNftId, expectedObjectType);
        }

        checkLockingPeriod(targetNftId, initialLockingPeriod);
        checkRewardRate(targetNftId, initialRewardRate);

        // target nft id must be known and registered with the expected object type
        if (!registry.isRegistered(targetNftId)) {
            revert IStaking.ErrorStakingTargetNotFound(targetNftId);
        } else {
            // check that expected object type matches with registered object type
            ObjectType actualObjectType = registry.getObjectInfo(targetNftId).objectType;
            if (actualObjectType != expectedObjectType) {
                revert IStaking.ErrorStakingTargetUnexpectedObjectType(targetNftId, expectedObjectType, actualObjectType);
            }
        }
    }


    function isTargetTypeSupported(ObjectType objectType)
        public 
        pure 
        returns (bool isSupported)
    {
        if(objectType == PROTOCOL()) { return true; }
        if(objectType == INSTANCE()) { return true; }

        return false;
    }


    function checkLockingPeriod(NftId targetNftId, Seconds lockingPeriod)
        public 
        pure
    {
        // check locking period is >= min locking period
        if (lockingPeriod.lt(getMinimumLockingPeriod())) {
            revert IStaking.ErrorStakingLockingPeriodTooShort(targetNftId, getMinimumLockingPeriod(), lockingPeriod);
        }

        // check locking period <= max locking period
        if (lockingPeriod > getMaxLockingPeriod()) {
            revert IStaking.ErrorStakingLockingPeriodTooLong(targetNftId, getMaxLockingPeriod(), lockingPeriod);
        }
    }


    function checkRewardRate(NftId targetNftId, UFixed rewardRate)
        public
        pure
    {
        // check reward rate <= max reward rate
        if (rewardRate > getMaxRewardRate()) {
            revert IStaking.ErrorStakingRewardRateTooHigh(targetNftId, getMaxRewardRate(), rewardRate);
        }
    }


    function calculateRequiredDipAmount(
        Amount tokenAmount,
        UFixed stakingRate
    )
        public
        pure
        returns (Amount dipAmount)
    {
        dipAmount = tokenAmount.multiplyWith(stakingRate);
    }


    function calculateStakingRate(
        IERC20Metadata dipToken,
        IERC20Metadata token,
        UFixed requiredDipPerToken
    )
        public
        view
        returns (UFixed stakingRate)
    {
        UFixed decimalsFactor = UFixedLib.toUFixed(1, int8(dipToken.decimals() - token.decimals()));
        stakingRate = requiredDipPerToken * decimalsFactor;
    }


    function getMaxLockingPeriod() public pure returns (Seconds maxLockingPeriod) {
        return SecondsLib.toSeconds(5 * 365 * 24 * 3600);
    }


    function getDefaultLockingPeriod() public pure returns (Seconds maxLockingPeriod) {
        return SecondsLib.toSeconds(365 * 24 * 3600 / 2);
    }

    /// @dev the minimum locking period is 24 hours
    function getMinimumLockingPeriod() public pure returns (Seconds minLockingPeriod) {
        return SecondsLib.toSeconds(24 * 3600);
    }

    function getMaxRewardRate() public pure returns (UFixed maxRewardRate) {
        return UFixedLib.toUFixed(33, -2);
    }


    function getDefaultRewardRate() public pure returns (UFixed defaultRewardRate) {
        return UFixedLib.toUFixed(5, -2);
    }


    function toTargetKey(NftId targetNftId) public pure returns (Key32 targetKey) {
        return targetNftId.toKey32(TARGET());
    }
}