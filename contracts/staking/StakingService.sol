// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../type/Amount.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, POOL, REGISTRY, STAKE, STAKING} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";
import {Timestamp} from "../type/Timestamp.sol";


contract StakingService is 
    Service, 
    IStakingService
{
    // TODO decide and implement string spec for location calculation
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.StakingService.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant STAKING_SERVICE_LOCATION_V1 = 0x6548005c3f4340f82f348c576c0ff69f7f529cadd5ad41f96aae61abceeaa300;

    struct StakingServiceStorage {
        IStaking _staking;
    }

    function getDomain() public pure override returns(ObjectType) {
        return STAKING();
    }


    function create(
        NftId targetNftId,
        Amount amount
    )
        external
        virtual
        returns (
            NftId stakeNftId
        )
    {

    }


    function stake(
        NftId stakeNftId,
        Amount amount
    )
        external
        virtual
    {

    }


    function unstake(
        NftId stakeNftId,
        Amount amount
    )
        external
        virtual
    {

    }

    function close(
        NftId stakeNftId
    )
        external
        virtual
    {

    }

    function reStake(
        NftId stakeNftId,
        NftId newTargetNftId
    )
        external
        virtual
        returns (
            NftId newStakeNftId,
            Timestamp unlockedAt
        )
    {

    }


    function increaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        virtual
        returns (Amount totalValueLocked)
    {

    }


    function decreaseTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        virtual
        returns (Amount totalValueLocked)
    {

    }


    function setTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        virtual
    {

    }

    function getStaking()
        external
        virtual
        returns (IStaking staking)
    {
        return _getStakingServiceStorage()._staking;
    }


    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address registryAddress,
            address stakingAddress
        ) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        $._staking = _registerStaking(stakingAddress);

        registerInterface(type(IStakingService).interfaceId);
    }


    function _registerStaking(
        address stakingAddress
    )
        internal
        returns (IStaking staking)
    {
        // check if provided staking contract is already registred
        IRegistry.ObjectInfo memory stakingInfo = getRegistry().getObjectInfo(stakingAddress);
        if (stakingInfo.nftId.gtz()) {
            // registered object but wrong type
            if (stakingInfo.objectType != STAKING()) {
                revert ErrorStakingServiceNotStaking(stakingAddress);
            }

            // return correctly registered staking contract
            return IStaking(stakingAddress);
        }

        // check that contract implements IStaking
        if(!IStaking(stakingAddress).supportsInterface(type(IStaking).interfaceId)) {
            revert ErrorStakingServiceNotSupportingIStaking(stakingAddress);
        }

        address owner = msg.sender;
        IRegistryService(
            _getServiceAddress(REGISTRY())).registerStaking(
                IRegisterable(stakingAddress),
                owner);

        return IStaking(stakingAddress);
    }


    function _getStakingServiceStorage() private pure returns (StakingServiceStorage storage $) {
        assembly {
            $.slot := STAKING_SERVICE_LOCATION_V1
        }
    }
}