// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../type/Amount.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IStakingService} from "./IStakingService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, POOL, STAKE} from "../type/ObjectType.sol";
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
        IPoolService _poolService;
    }

    function getDomain() public pure override returns(ObjectType) {
        return STAKE();
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


    function sendTotalValueLockedData(
        NftId targetNftId,
        address token
    )
        external
        virtual
    {

    }


    function receiveTotalValueLockedData(
        NftId targetNftId,
        address token
    )
        external
        virtual
    {

    }


    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        // TODO check this, might no longer be the way, refactor if necessary
        address registryAddress;
        (registryAddress,) = abi.decode(data, (address, address));

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        $._poolService = IPoolService(_getServiceAddress(POOL()));

        initializeService(registryAddress, address(0), owner);
        registerInterface(type(IStakingService).interfaceId);
    }

    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, getVersion().toMajorPart());
    }

    function _getStakingServiceStorage() private pure returns (StakingServiceStorage storage $) {
        assembly {
            $.slot := STAKING_SERVICE_LOCATION_V1
        }
    }
}