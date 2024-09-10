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


    /// @inheritdoc IStakingService
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


    /// @inheritdoc IStakingService
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


    /// @inheritdoc IStakingService
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


    /// @inheritdoc IStakingService
    function refillInstanceRewardReserves(NftId instanceNftId, address rewardProvider, Amount dipAmount)
        external
        virtual
        restricted()
        returns (Amount newBalance)
    {
        // checks
        _checkNftType(instanceNftId, INSTANCE());

        // update reward reserve book keeping
        StakingServiceStorage storage $ = _getStakingServiceStorage();
        newBalance = $._staking.refillRewardReserves(instanceNftId, dipAmount);

        emit LogStakingServiceRewardReservesIncreased(instanceNftId, rewardProvider, dipAmount, newBalance);
    }


    /// @inheritdoc IStakingService
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
    }


    /// @inheritdoc IStakingService
    function createStakeObject(
        NftId targetNftId,
        address stakeOwner
    )
        external
        virtual
        restricted()
        onlyStaking()
        returns (NftId stakeNftId)
    {
        StakingServiceStorage storage $ = _getStakingServiceStorage();

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

        emit LogStakingServiceStakeObjectCreated(stakeNftId, targetNftId, stakeOwner);
    }


    /// @inheritdoc IStakingService
    function pullDipToken(Amount dipAmount, address stakeOwner)
        external
        virtual
        restricted()
        onlyStaking()
    {
        _getStakingServiceStorage()._tokenHandler.pullToken(stakeOwner, dipAmount);
    }


    /// @inheritdoc IStakingService
    function pushDipToken(Amount dipAmount, address stakeOwner)
        external
        virtual
        restricted()
        onlyStaking()
    {
        _getStakingServiceStorage()._tokenHandler.pushToken(stakeOwner, dipAmount);
    }


    /// @inheritdoc IStakingService
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


    function _getStakingServiceStorage() private pure returns (StakingServiceStorage storage $) {
        assembly {
            $.slot := STAKING_SERVICE_LOCATION_V1
        }
    }


    function _getDomain() internal pure override returns(ObjectType) {
        return STAKING();
    }
}