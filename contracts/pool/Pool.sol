// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {BUNDLE, COMPONENT, POLICY, POOL} from "../type/ObjectType.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IBundleService} from "./IBundleService.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IPoolComponent} from "./IPoolComponent.sol";
import {IPoolService} from "./IPoolService.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "../shared/IComponentService.sol";
import {InstanceLinkedComponent} from "../shared/InstanceLinkedComponent.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {Fee} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId, PUBLIC_ROLE} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";

abstract contract Pool is
    InstanceLinkedComponent, 
    IPoolComponent 
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Pool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant POOL_STORAGE_LOCATION_V1 = 0x25e3e51823fbfffb988e0a2744bb93722d9f3e906c07cc0a9e77884c46c58300;

    struct PoolStorage {
        IComponents.PoolInfo _poolInfo;
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


    // TODO remove function once this is no longer used to produce contract locations on the fly ...
    function getContractLocation(bytes memory name) external pure returns (bytes32 hash) {
        return keccak256(abi.encode(uint256(keccak256(name)) - 1)) & ~bytes32(uint256(0xff));
    }


    /// @dev see {IPoolComponent.verifyApplication}
    function verifyApplication(
        NftId applicationNftId, 
        NftId bundleNftId, 
        Amount collateralizationAmount
    )
        public
        virtual
        restricted()
        onlyNftOfType(applicationNftId, POLICY())
    {
        InstanceReader reader = _getInstanceReader();
        if(!applicationMatchesBundle(
            applicationNftId,
            reader.getPolicyInfo(applicationNftId).applicationData, 
            bundleNftId, 
            reader.getBundleInfo(bundleNftId).filter,
            collateralizationAmount)
        )
        {
            revert ErrorPoolApplicationBundleMismatch(applicationNftId);
        }

        emit LogPoolVerifiedByPool(address(this), applicationNftId, collateralizationAmount);
    }


    /// @dev see {IPoolComponent.processConfirmedClaim}
    function processConfirmedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount amount
    )
        public
        virtual
        restricted()
        onlyNftOfType(policyNftId, POLICY())
    {
        // default implementation is empty
    }


    /// @dev see {IPoolComponent.applicationMatchesBundle}
    /// Default implementation always returns true.
    /// Override this function to implement any custom application verification.
    /// Calling super.applicationMatchesBundle will ensure validation of application and bundle nft ids.
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
        onlyNftOfType(applicationNftId, POLICY())
        onlyNftOfType(bundleNftId, BUNDLE())
        returns (bool isMatching)
    {
        return true;
    }


    function getInitialPoolInfo()
        public 
        virtual 
        view 
        returns (IComponents.PoolInfo memory poolInfo)
    {
        return _getPoolStorage()._poolInfo;
    }

    // Internals

    function _initializePool(
        address registry,
        NftId productNftId,
        string memory name,
        address token,
        IComponents.PoolInfo memory poolInfo,
        IAuthorization authorization,
        address initialOwner,
        bytes memory componentData // component specifidc data 
    )
        internal
        virtual
        onlyInitializing()
    {
        _initializeInstanceLinkedComponent(
            registry, 
            productNftId,  
            name, 
            token, 
            POOL(), 
            authorization, 
            poolInfo.isInterceptingBundleTransfers, 
            initialOwner, 
            componentData);

        PoolStorage storage $ = _getPoolStorage();

        $._poolInfo = poolInfo;
        $._poolService = IPoolService(_getServiceAddress(POOL())); 
        $._bundleService = IBundleService(_getServiceAddress(BUNDLE()));
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        _registerInterface(type(IPoolComponent).interfaceId);
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


    /// @dev Sets the maximum balance amound held by this pool.
    /// Function may only be called by pool owner.
    function _setMaxBalanceAmount(Amount maxBalanceAmount)
        internal
        virtual
    {
        _getPoolStorage()._poolService.setMaxBalanceAmount(maxBalanceAmount);
    }


    /// @dev Fund the pool wallet with the specified amount.
    /// Function is only available for externally managed pools.
    function _fundPoolWallet(Amount amount)
        internal
        virtual
    {
        _getPoolStorage()._poolService.fundPoolWallet(amount);
    }


    /// @dev Withdraw the specified amount from the pool wallet.
    /// Function is only available for externally managed pools.
    function _defundPoolWallet(Amount amount)
        internal
        virtual
    {
        _getPoolStorage()._poolService.defundPoolWallet(amount);
    }


    /// @dev Creates a new empty bundle using the provided parameter values.
    function _createBundle(
        address bundleOwner,
        Fee memory fee,
        Seconds lifetime, 
        bytes memory filter
    )
        internal
        returns(NftId bundleNftId)
    {
        bundleNftId = _getPoolStorage()._poolService.createBundle(
            bundleOwner,
            fee,
            lifetime,
            filter);

        // TODO add logging
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


    /// @dev Withdraws the specified amount of fees from the bundle.
    function _withdrawBundleFees(NftId bundleNftId, Amount amount) 
        internal
        returns (Amount withdrawnAmount) 
    {
        return _getPoolStorage()._bundleService.withdrawBundleFees(bundleNftId, amount);
    }


    /// @dev increases the staked tokens by the specified amount
    /// bundle MUST be in active or locked state
    function _stake(
        NftId bundleNftId, 
        Amount amount
    )
        internal
        virtual
        returns(Amount) 
    {
        return _getPoolStorage()._poolService.stake(bundleNftId, amount);
    }


    /// @dev decreases the staked tokens by the specified amount
    /// bundle MUST be in active, locked or closed state
    function _unstake(
        NftId bundleNftId, 
        Amount amount
    )
        internal
        virtual
        returns(Amount netAmount) 
    {
        return _getPoolStorage()._poolService.unstake(bundleNftId, amount);
    }


    /// @dev extends the bundle lifetime of the bundle by the specified time
    /// bundle MUST be in active or locked state
    function _extend(
        NftId bundleNftId, 
        Seconds lifetimeExtension
    )
        internal
        virtual
        returns (Timestamp extendedExpiredAt) 
    {
        return _getPoolStorage()._bundleService.extend(bundleNftId, lifetimeExtension);
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
    function _closeBundle(NftId bundleNftId)
        internal
        virtual
    {
        _getPoolStorage()._poolService.closeBundle(bundleNftId);
    }


    function _processFundedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount availableAmount
    )
        internal
    {
        _getPoolStorage()._poolService.processFundedClaim(
            policyNftId, claimId, availableAmount);
    }


    function _getPoolStorage() private pure returns (PoolStorage storage $) {
        assembly {
            $.slot := POOL_STORAGE_LOCATION_V1
        }
    }
}
