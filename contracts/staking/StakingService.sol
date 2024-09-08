// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IStaking} from "./IStaking.sol";
import {IStakingService} from "./IStakingService.sol";

import {Amount} from "../type/Amount.sol";
import {RegistryService} from "../registry/RegistryService.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType, INSTANCE, REGISTRY, STAKE, STAKING} from "../type/ObjectType.sol";
import {Seconds} from "../type/Seconds.sol";
import {Service} from "../shared/Service.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
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
        IERC20Metadata _dip;
        TokenHandler _tokenHandler;
    }


    modifier onlyStaking() {
        if (msg.sender != address(_getStakingServiceStorage()._staking)) {
            revert ErrorStakingServiceNotStaking(msg.sender);
        }
        _;
    }


    function approveTokenHandler(
        IERC20Metadata token,
        Amount amount
    )
        external
        virtual
        onlyStaking()
    {
        _getStakingServiceStorage()._tokenHandler.approve(token, amount);
    }


    /// @inheritdoc IStakingService
    function createInstanceTarget(
        NftId targetNftId,
        Seconds initialLockingPeriod,
        UFixed initialRewardRate
    )
        external
        virtual
        restricted()
    {
        uint256 chainId = block.chainid;
        _getStakingServiceStorage()._staking.registerTarget(
            targetNftId,
            INSTANCE(),
            initialLockingPeriod,
            initialRewardRate);

        emit LogStakingServiceInstanceTargetRegistered(targetNftId, chainId);
    }


    function setInstanceLockingPeriod(NftId instanceNftId, Seconds lockingPeriod)
        external
        virtual
        restricted()
    {
        _checkNftType(instanceNftId, INSTANCE());
        _getStakingServiceStorage()._staking.setLockingPeriod(
            instanceNftId, 
            lockingPeriod);
    }


    function setInstanceRewardRate(NftId instanceNftId, UFixed rewardRate)
        external
        virtual
        restricted()
    {
        _checkNftType(instanceNftId, INSTANCE());
        _getStakingServiceStorage()._staking.setRewardRate(
            instanceNftId, 
            rewardRate);
    }

    function setInstanceMaxStakedAmount(NftId instanceNftId, Amount maxStakingAmount)
        external
        virtual
        restricted()
    {
        _checkNftType(instanceNftId, INSTANCE());
        _getStakingServiceStorage()._staking.setMaxStakedAmount(
            instanceNftId, 
            maxStakingAmount);
    }


    function refillInstanceRewardReserves(NftId instanceNftId, address rewardProvider, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        _checkNftType(instanceNftId, INSTANCE());
        return _refillRewardReserves(instanceNftId, rewardProvider, dipAmount);
    }


    function refillRewardReservesBySender(NftId targetNftId, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        address rewardProvider = msg.sender;
        return _refillRewardReserves(targetNftId, rewardProvider, dipAmount);
    }


    function withdrawInstanceRewardReserves(NftId instanceNftId, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        _checkNftType(instanceNftId, INSTANCE());
        // update reward reserve book keeping
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        newBalance = $._staking.withdrawRewardReserves(instanceNftId, dipAmount);

        // transfer withdrawal amount to target owner
        address instanceOwner = getRegistry().ownerOf(instanceNftId);
        emit LogStakingServiceRewardReservesDecreased(instanceNftId, instanceOwner, dipAmount, newBalance);
        $._tokenHandler.pushToken(
            instanceOwner,
            dipAmount);
    }

    function createStakeObject(
        NftId targetNftId,
        address initialOwner
    )
        external
        virtual
        restricted()
        onlyStaking()
        returns (NftId stakeNftId)
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        // target nft id checks are performed in $._staking.createStake() below
        // register new stake object with registry
        stakeNftId = $._registryService.registerStake(
            IRegistry.ObjectInfo({
                nftId: NftIdLib.zero(),
                parentNftId: targetNftId,
                objectType: STAKE(),
                isInterceptor: false,
                objectAddress: address(0),
                initialOwner: initialOwner,
                data: ""
            }));

        emit LogStakingServiceStakeObjectCreated(stakeNftId, targetNftId, stakeOwner);
    }


    /// @dev Creates a new stake object via regisry Service.
    /// Funds are stakedto the specified target nft id with the provided dip amount
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
        restricted()
        returns (
            NftId stakeNftId
        )
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        // target nft id checks are performed in $._staking.createStake() below
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

        // create stake info with staking
        $._staking.createStake(
            stakeNftId, 
            targetNftId,
            dipAmount);

        emit LogStakingServiceStakeCreated(stakeNftId, targetNftId, stakeOwner, dipAmount);

        // collect staked dip by staking
        $._tokenHandler.pullToken(
            stakeOwner, 
            dipAmount);
    }


    function stake(
        NftId stakeNftId,
        Amount dipAmount
    )
        external
        virtual
        restricted()
        onlyNftOwner(stakeNftId)
    {
        _checkNftType(stakeNftId, STAKE());

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        // add additional staked dips by staking 
        Amount stakeBalance = $._staking.stake(
            stakeNftId, 
            dipAmount);

        // collect staked dip by staking
        if (dipAmount.gtz()) {
            emit LogStakingServiceStakeIncreased(stakeNftId, stakeOwner, dipAmount, stakeBalance);
        $._tokenHandler.pullToken(
                stakeOwner,
                dipAmount);
        }
    }

    // TODO cleanup
    // function restakeToNewTarget(
    //     NftId stakeNftId,
    //     NftId newTargetNftId
    // )
    //     external
    //     virtual
    //     restricted()
    //     onlyNftOwner(stakeNftId)
    //     returns (
    //         NftId newStakeNftId,
    //         Amount newStakeBalance
    //     )
    // {
    //     _checkNftType(stakeNftId, STAKE());

    //     StakingServiceStorage storage $ = _getStakingServiceStorage();
    //     address stakeOwner = msg.sender;

    //     if (! getRegistry().isRegistered(newTargetNftId)) {
    //         revert ErrorStakingServiceTargetUnknown(newTargetNftId);
    //     }

    //     // register new stake object with registry
    //     newStakeNftId = $._registryService.registerStake(
    //         IRegistry.ObjectInfo({
    //             nftId: NftIdLib.zero(),
    //             parentNftId: newTargetNftId,
    //             objectType: STAKE(),
    //             isInterceptor: false,
    //             objectAddress: address(0),
    //             initialOwner: stakeOwner,
    //             data: ""
    //         }));

    //     newStakeBalance = $._staking.restake(
    //         stakeNftId, 
    //         newStakeNftId);

    //     emit LogStakingServiceStakeRestaked(stakeOwner, stakeNftId, newStakeNftId, newTargetNftId, newStakeBalance);
    // } 


    function updateRewards(
        NftId stakeNftId
    )
        external
        virtual
        restricted()
    {
        _checkNftType(stakeNftId, STAKE());

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        $._staking.updateRewards(stakeNftId);

        emit LogStakingServiceRewardsUpdated(stakeNftId);
    }


    function claimRewards(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyNftOwner(stakeNftId)
    {
        _checkNftType(stakeNftId, STAKE());

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        Amount rewardsClaimedAmount = $._staking.claimRewards(stakeNftId);
        emit LogStakingServiceRewardsClaimed(stakeNftId, stakeOwner, rewardsClaimedAmount);
        $._tokenHandler.pushToken(
            stakeOwner,
            rewardsClaimedAmount);
    }


    function unstake(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyNftOwner(stakeNftId)
    {
        _checkNftType(stakeNftId, STAKE());
        
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        ) = $._staking.unstake(stakeNftId);

        Amount totalAmount = unstakedAmount + rewardsClaimedAmount;
        emit LogStakingServiceUnstaked(stakeNftId, stakeOwner, totalAmount);

        $._tokenHandler.pushToken(
            stakeOwner, 
            totalAmount);
    }


    function setTotalValueLocked(
        NftId targetNftId,
        address token,
        Amount amount
    )
        external
        virtual
        restricted()
    {
        // TODO implement

    }

    //--- view functions ----------------------------------------------------//

    function getDipToken()
        external
        view
        virtual
        returns (IERC20Metadata dip)
    {
        return _getStakingServiceStorage()._dip;
    }


    function getTokenHandler()
        external
        view
        virtual
        returns (TokenHandler tokenHandler)
    {
        return _getStakingServiceStorage()._tokenHandler;
    }


    function getStaking()
        external
        view
        virtual
        returns (IStaking staking)
    {
        return _getStakingServiceStorage()._staking;
    }

    //--- internal functions ------------------------------------------------//

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address authority,
            address registry,
            address staking
        ) = abi.decode(data, (address, address, address));

        __Service_init(authority, registry, owner);

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        $._registryService = RegistryService(_getServiceAddress(REGISTRY()));
        $._staking = _registerStaking(staking);
        $._dip = $._staking.getToken();
        $._tokenHandler = $._staking.getTokenHandler();

        _registerInterface(type(IStakingService).interfaceId);
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


    function _refillRewardReserves(NftId targetNftId, address rewardProvider, Amount dipAmount)
        internal
        virtual
        returns (Amount newBalance)
    {
        // update reward reserve book keeping
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        newBalance = $._staking.refillRewardReserves(targetNftId, dipAmount);

        emit LogStakingServiceRewardReservesIncreased(targetNftId, rewardProvider, dipAmount, newBalance);

        // collect reward dip from provider
        $._tokenHandler.pullToken(
            rewardProvider,
            dipAmount);
    }


    function _getStakingServiceStorage() private pure returns (StakingServiceStorage storage $) {
        assembly {
            $.slot := STAKING_SERVICE_LOCATION_V1
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return STAKING();
    }
}