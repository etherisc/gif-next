// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {BUNDLE, COMPONENT, POOL} from "../type/ObjectType.sol";
import {IBundleService} from "./IBundleService.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "./IPoolService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {Fee, FeeLib} from "../type/Fee.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";

abstract contract Pool is
    InstanceLinkedComponent, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
        IComponentService _componentService;
        IPoolService _poolService;
        IBundleService _bundleService;
    }


    modifier onlyBundleOwner(NftId bundleNftId) {
        if(msg.sender != getRegistry().ownerOf(bundleNftId)) {
            revert ErrorPoolNotBundleOwner(bundleNftId, msg.sender);
        }
        _;
    }


    /// @dev see {IPoolComponent.verifyApplication}
    function verifyApplication(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    )
        public
        virtual
        restricted()
    {
        if(!applicationMatchesBundle(
            applicationNftId,
            applicationData, 
            bundleNftId, 
            bundleFilter,
            collateralizationAmount)
        )
        {
            revert ErrorPoolApplicationBundleMismatch(applicationNftId);
        }

        emit LogPoolVerifiedByPool(address(this), applicationNftId, collateralizationAmount);
    }


    /// @dev see {IPoolComponent.applicationMatchesBundle}
    /// Override this function to implement any custom application verification 
    /// Default implementation always returns true
    function applicationMatchesBundle(
        NftId applicationNftId, 
        bytes memory applicationData,
        NftId bundleNftId, 
        bytes memory bundleFilter,
        Amount collateralizationAmount
    )
        public
        virtual
        view
        returns (bool isMatching)
    {
        return true;
    }


    function register()
        external
        virtual
        onlyOwner()
    {
        _getPoolStorage()._componentService.registerPool();
        _approveTokenHandler(type(uint256).max);
    }

    /// @inheritdoc IPoolComponent
    function withdrawBundleFees(NftId bundleNftId, Amount amount) 
        external 
        virtual
        restricted()
        onlyBundleOwner(bundleNftId)
        returns (Amount withdrawnAmount) 
    {
        return _withdrawBundleFees(bundleNftId, amount);
    }


    function getInitialPoolInfo()
        public 
        virtual 
        view 
        returns (IComponents.PoolInfo memory poolInfo)
    {
        return IComponents.PoolInfo(
            NftIdLib.zero(), // will be set when GIF registers the related product
            PUBLIC_ROLE(), // bundleOwnerRole
            AmountLib.max(), // maxCapitalAmount,
            isNftInterceptor(), // isInterceptingBundleTransfers
            false, // isExternallyManaged,
            false, // isVerifyingApplications,
            UFixedLib.toUFixed(1), // collateralizationLevel,
            UFixedLib.toUFixed(1), // retentionLevel,
            FeeLib.zero(), // initialPoolFee,
            FeeLib.zero(), // initialStakingFee,
            FeeLib.zero() // initialPerformanceFee,
        );
    }

    // Internals

    function _initializePool(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        IAuthorization authorization,
        bool isInterceptingNftTransfers,
        address initialOwner,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // component specifidc data 
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeInstanceLinkedComponent(
            registry, 
            instanceNftId, 
            name, 
            token, 
            POOL(), 
            authorization, 
            isInterceptingNftTransfers, 
            initialOwner, 
            registryData, 
            componentData);

        PoolStorage storage $ = _getPoolStorage();
        $._poolService = IPoolService(_getServiceAddress(POOL())); 
        $._bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        registerInterface(type(IPoolComponent).interfaceId);
    }

    /// @dev increases the staked tokens by the specified amount
    /// bundle MUST be in active or locked state
    function _stake(
        NftId bundleNftId, 
        Amount amount
    )
        internal
        virtual
    {
        // TODO add implementation
    }


    /// @dev decreases the staked tokens by the specified amount
    /// bundle MUST be in active, locked or closed state
    function _unstake(
        NftId bundleNftId, 
        Amount amount
    )
        internal
        virtual
    {
        // TODO add implementation
    }


    /// @dev extends the bundle lifetime of the bundle by the specified time
    /// bundle MUST be in active or locked state
    function _extend(
        NftId bundleNftId, 
        Seconds lifetimeExtension
    )
        internal
        virtual
    {
        // TODO add implementation
    }


    /// @dev Locks the specified bundle.
    /// A bundle to be locked MUST be in active state.
    /// Locked bundles may not be used to collateralize any new policy.
    function _lockBundle(NftId bundleNftId)
        internal
        virtual
    {
        _getPoolStorage()._bundleService.lock(bundleNftId);
    }


    /// @dev Unlocks the specified bundle.
    /// A bundle to be unlocked MUST be in locked state.
    function _unlockBundle(NftId bundleNftId)
        internal
        virtual
    {
        _getPoolStorage()._bundleService.unlock(bundleNftId);
    }


    /// @dev Close the specified bundle.
    /// A bundle to be closed MUST be in active or locked state.
    /// To close a bundle all all linked policies MUST be in closed state as well.
    /// Closing a bundle finalizes the bundle bookkeeping including overall profit calculation.
    /// Once a bundle is closed this action cannot be reversed.
    function _close(NftId bundleNftId)
        internal
        virtual
    {
        _getPoolStorage()._poolService.closeBundle(bundleNftId);
    }


    /// @dev Sets the fee for the specified bundle.
    /// The fee is added on top of the poolFee and deducted from the premium amounts
    /// Via these fees individual bundler owner may earn income per policy in the context of peer to peer pools.
    function _setBundleFee(
        NftId bundleNftId, 
        Fee memory fee
    )
        internal
        virtual
    {
        _getPoolStorage()._bundleService.setFee(bundleNftId, fee);
    }


    /// @dev Sets the maximum overall capital amound held by this pool.
    /// Function may only be called by pool owner.
    function _setMaxCapitalAmount(Amount maxCapitalAmount)
        internal
        virtual
    {
        _getPoolStorage()._poolService.setMaxCapitalAmount(maxCapitalAmount);
    }

    /// @dev Sets the required role to create/own bundles.
    /// May only be called once after setting up a pool.
    /// May only be called by pool owner.
    function _setBundleOwnerRole(RoleId bundleOwnerRole)
        internal
        virtual
    {
        _getPoolStorage()._poolService.setBundleOwnerRole(bundleOwnerRole);
    }


    /// @dev Update pool fees to the specified values.
    /// Pool fee: are deducted from the premium amount and goes to the pool owner.
    /// Staking fee: are deducted from the staked tokens by a bundle owner and goes to the pool owner.
    /// Performance fee: when a bundle is closed a bundle specific profit is calculated.
    /// The performance fee is deducted from this profit and goes to the pool owner.
    function _setPoolFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        internal
        virtual
    {
        _getPoolStorage()._componentService.setPoolFees(poolFee, stakingFee, performanceFee);
    }

    /// @dev Creates a new bundle using the provided parameter values.
    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        Amount amount,
        Seconds lifetime, 
        bytes memory filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _getPoolStorage()._poolService.createBundle(
            bundleOwner,
            fee,
            amount,
            lifetime,
            filter);

        // TODO add logging
    }

    // TODO remove function once this is no longer used to produce contract locations on the fly ...
    function getContractLocation(bytes memory name) external pure returns (bytes32 hash) {
        return keccak256(abi.encode(uint256(keccak256(name)) - 1)) & ~bytes32(uint256(0xff));
    }

    function _withdrawBundleFees(NftId bundleNftId, Amount amount) 
        internal
        returns (Amount withdrawnAmount) 
    {
        return _getPoolStorage()._bundleService.withdrawBundleFees(bundleNftId, amount);
    }

    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
