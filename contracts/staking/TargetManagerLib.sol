// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IStaking} from "./IStaking.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ChainIdLib} from "../type/ChainId.sol";
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

        ObjectType targetType = reader.getTargetInfo(targetNftId).objectType;
        checkLockingPeriod(reader, targetNftId, targetType, lockingPeriod);

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

        ObjectType targetType = reader.getTargetInfo(targetNftId).objectType;
        checkRewardRate(reader, targetNftId, targetType, rewardRate);

        targetInfo = reader.getTargetInfo(targetNftId);
        oldRewardRate = targetInfo.rewardRate;

        targetInfo.rewardRate = rewardRate;
    }


    function checkTargetParameters(
        IRegistry registry,
        StakingReader stakingReader,
        NftId targetNftId,
        ObjectType expectedObjectType,
        Seconds lockingPeriod,
        UFixed rewardRate
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

        // get setup info for additional checks
        IStaking.SupportInfo memory supportInfo = stakingReader.getSupportInfo(expectedObjectType);

        // check if type is supported and new targets of that type are allowed
        if (!(supportInfo.isSupported && supportInfo.allowNewTargets)) {
            revert IStaking.ErrorStakingTargetTypeNotSupported(targetNftId, expectedObjectType);
        }

        // check if cross chain targets are allowed (if applicable)
        bool isCurrentChain = ChainIdLib.isCurrentChain(targetNftId);
        if (!supportInfo.allowCrossChain && !isCurrentChain) {
            revert IStaking.ErrorStakingCrossChainTargetsNotSupported(targetNftId, expectedObjectType);
        }

        // additional check for current chain target: target nft id must be known and registered with the expected object type
        if (isCurrentChain) {
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

        // check locking period and reward rate
        _checkLockingPeriod(targetNftId, lockingPeriod, supportInfo);
        _checkRewardRate(targetNftId, rewardRate, supportInfo);
    }


    function checkLockingPeriod(StakingReader reader, NftId targetNftId, ObjectType targetType, Seconds lockingPeriod)
        public 
        view
    {
        IStaking.SupportInfo memory supportInfo = reader.getSupportInfo(targetType);
        _checkLockingPeriod(targetNftId, lockingPeriod, supportInfo);
    }


    function checkRewardRate(StakingReader reader, NftId targetNftId, ObjectType targetType, UFixed rewardRate)
        public
        view
    {
        IStaking.SupportInfo memory supportInfo = reader.getSupportInfo(targetType);
        _checkRewardRate(targetNftId, rewardRate, supportInfo);
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


    function _checkLockingPeriod(NftId targetNftId, Seconds lockingPeriod, IStaking.SupportInfo memory supportInfo)
        private
        pure
    {
        if (lockingPeriod < supportInfo.minLockingPeriod || lockingPeriod > supportInfo.maxLockingPeriod) {
            revert IStaking.ErrorStakingLockingPeriodInvalid(
                targetNftId, 
                lockingPeriod, 
                supportInfo.minLockingPeriod,
                supportInfo.maxLockingPeriod);
        }
    }


    function _checkRewardRate(NftId targetNftId, UFixed rewardRate, IStaking.SupportInfo memory supportInfo) 
        private
        pure
    {
        if (rewardRate < supportInfo.minRewardRate || rewardRate > supportInfo.maxRewardRate) {
            revert IStaking.ErrorStakingRewardRateInvalid(
                targetNftId, 
                rewardRate,
                supportInfo.minRewardRate,
                supportInfo.maxRewardRate);
        }
    }
}