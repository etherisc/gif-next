// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
import {StakeManagerLib} from "./StakeManagerLib.sol";
import {StakingReader} from "./StakingReader.sol";
import {TargetManagerLib} from "./TargetManagerLib.sol";
import {Timestamp} from "../type/Timestamp.sol";
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

    modifier onlyNftOwner(NftId nftId) {
        if(msg.sender != getRegistry().ownerOf(nftId)) {
            revert ErrorStakingServiceNotNftOwner(nftId, getRegistry().ownerOf(nftId), msg.sender);
        }
        _;
    }


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
            chainId,
            initialLockingPeriod,
            initialRewardRate);

        emit LogStakingServiceInstanceTargetRegistered(targetNftId, chainId);
    }


    function setInstanceLockingPeriod(NftId instanceNftId, Seconds lockingPeriod)
        external
        virtual
        restricted()
    {
        _getStakingServiceStorage()._staking.setLockingPeriod(
            instanceNftId, 
            lockingPeriod);
    }


    function setInstanceRewardRate(NftId instanceNftId, UFixed rewardRate)
        external
        virtual
        restricted()
    {
        _getStakingServiceStorage()._staking.setRewardRate(
            instanceNftId, 
            rewardRate);
    }


    function refillInstanceRewardReserves(NftId instanceNftId, address rewardProvider, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
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
        // update reward reserve book keeping
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        newBalance = $._staking.withdrawRewardReserves(instanceNftId, dipAmount);

        // transfer withdrawal amount to target owner
        address instanceOwner = getRegistry().ownerOf(instanceNftId);
        $._staking.transferDipAmount(
            instanceOwner,
            dipAmount);

        emit LogStakingServiceRewardReservesDecreased(instanceNftId, instanceOwner, dipAmount, newBalance);
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

        // collect staked dip by staking
        $._staking.collectDipAmount(
            stakeOwner,
            dipAmount);

        emit LogStakingServiceStakeCreated(stakeNftId, targetNftId, stakeOwner, dipAmount);
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
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        // add additional staked dips by staking 
        Amount stakeBalance = $._staking.stake(
            stakeNftId, 
            dipAmount);

        // collect staked dip by staking
        if (dipAmount.gtz()) {
            $._staking.collectDipAmount(
                stakeOwner,
                dipAmount);
        }

        emit LogStakingServiceStakeIncreased(stakeNftId, stakeOwner, dipAmount, stakeBalance);
    }


    function restakeToNewTarget(
        NftId stakeNftId,
        NftId newTargetNftId
    )
        external
        virtual
        restricted()
        onlyNftOwner(stakeNftId)
        returns (
            NftId newStakeNftId
        )
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        // TODO implement
    } 


    function updateRewards(
        NftId stakeNftId
    )
        external
        virtual
        restricted()
    {
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
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        Amount rewardsClaimedAmount = $._staking.claimRewards(stakeNftId);
        $._staking.transferDipAmount(
            stakeOwner,
            rewardsClaimedAmount);

        emit LogStakingServiceRewardsClaimed(stakeNftId, stakeOwner, rewardsClaimedAmount);
    }


    function unstake(NftId stakeNftId)
        external
        virtual
        restricted()
        onlyNftOwner(stakeNftId)
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        address stakeOwner = msg.sender;

        (
            Amount unstakedAmount,
            Amount rewardsClaimedAmount
        ) = $._staking.unstake(stakeNftId);

        Amount totalAmount = unstakedAmount + rewardsClaimedAmount;
        $._staking.transferDipAmount(
            stakeOwner,
            totalAmount);

        emit LogStakingServiceUnstaked(stakeNftId, stakeOwner, totalAmount);
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
        virtual
        returns (IERC20Metadata dip)
    {
        return _getStakingServiceStorage()._dip;
    }


    function getTokenHandler()
        external
        virtual
        returns (TokenHandler tokenHandler)
    {
        return _getStakingServiceStorage()._tokenHandler;
    }


    function getStaking()
        external
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
            address registryAddress,
            address stakingAddress
        ) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);

        StakingServiceStorage storage $ = _getStakingServiceStorage();
        $._registryService = RegistryService(_getServiceAddress(REGISTRY()));
        $._staking = _registerStaking(stakingAddress);
        $._dip = $._staking.getToken();
        $._tokenHandler = $._staking.getTokenHandler();

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


    function _refillRewardReserves(NftId targetNftId, address rewardProvider, Amount dipAmount)
        internal
        virtual
        returns (Amount newBalance)
    {
        // update reward reserve book keeping
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        newBalance = $._staking.refillRewardReserves(targetNftId, dipAmount);

        // collect reward dip from provider
        $._staking.collectDipAmount(
            rewardProvider,
            dipAmount);

        emit LogStakingServiceRewardReservesIncreased(targetNftId, rewardProvider, dipAmount, newBalance);
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