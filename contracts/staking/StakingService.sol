// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {ChainNft} from "../registry/ChainNft.sol";
import {IPoolService} from "../pool/IPoolService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, INSTANCE, PROTOCOL, REGISTRY, STAKE, STAKING} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {Service} from "../shared/Service.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";


contract StakingService is 
    Service, 
    IStakingService
{
    // TODO decide and implement string spec for location calculation
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.StakingService.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant STAKING_SERVICE_LOCATION_V1 = 0x6548005c3f4340f82f348c576c0ff69f7f529cadd5ad41f96aae61abceeaa300;

    struct StakingServiceStorage {
        RegistryService _registryService;
        IStaking _staking;
    }

    function getDomain() public pure override returns(ObjectType) {
        return STAKING();
    }


    function registerProtocolTarget()
        external
        virtual
    {
        uint256 protocolId = ChainNft(
            getRegistry().getChainNftAddress()).PROTOCOL_NFT_ID();

        NftId protocolNftId = NftIdLib.toNftId(protocolId);
        _getStakingServiceStorage()._staking.registerTarget(
            protocolNftId,
            PROTOCOL(),
            1, // protocol is registered on mainnet
            TargetManagerLib.getDefaultLockingPeriod(),
            TargetManagerLib.getDefaultRewardRate());
    }


    function createInstanceTarget(
        NftId targetNftId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    )
        external
        virtual
        // restricted // TODO re-enable once services have stable roles
    {
        uint256 chainId = block.chainid;
        _getStakingServiceStorage()._staking.registerTarget(
            targetNftId,
            INSTANCE(),
            chainId,
            initialLockingPeriod,
            initialRewardRate);
    }


    /// @dev creates a new stake to the specified target nft id with the provided dip amount
    /// the target nft id must have been registered as an active staking target prior to this call
    /// the sender of this transaction becomes the stake owner via the minted nft.
    /// to create the new stake balance and allowance of the staker need to cover the dip amount
    /// the allowance needs to be on the token handler of the staking contract (getTokenHandler())
    /// this is a permissionless function.
    function create(
        NftId targetNftId,
        Amount dipAmount
    )
        external
        virtual
        returns (
            NftId stakeNftId
        )
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        StakingReader stakingReader = $._staking.getStakingReader();
        address stakeOwner = msg.sender;

        // check target nft id
        if (targetNftId.eqz()) {
            revert ErrorStakingServiceZeroTargetNftId();
        }

        if (!stakingReader.isTarget(targetNftId)) {
            revert ErrorStakingServiceNotTargetNftId(targetNftId);
        }

        if (!stakingReader.isActive(targetNftId)) {
            revert ErrorStakingServiceNotActiveTargetNftId(targetNftId);
        }

        // check balance and allowance
        //TODO implement

        // collect staked dip amount
        //TODO implement

        // register new stake object with registry
        stakeNftId = $._registryService.registerStake(
            IRegistry.ObjectInfo({
                nftId: NftIdLib.zero(),
                parentNftId: targetNftId,
                objectType: STAKE(),
                isInterceptor: false,
                objectAddress: address(0),
                initialOwner: stakeOwner,
                data: ""
            }));
        
        // create stake info in staking
        $._staking.create(
            stakeNftId, 
            targetNftId,
            dipAmount);

        emit LogStakingServiceNewStakeCreated(stakeNftId, stakeOwner, targetNftId, dipAmount);
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
        $._registryService = RegistryService(_getServiceAddress(REGISTRY()));
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
        // staking contract may have been already registered by a previous major relase
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
        _getStakingServiceStorage()._registryService.registerStaking(
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