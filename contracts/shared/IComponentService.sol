// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev component base class
/// component examples are staking, product, distribution, pool and oracle
interface IComponentService is 
    IService
{
    error ErrorComponentServiceNotInstanceLinkedComponent(address component);
    error ErrorComponentServiceSenderNotRegistered(address sender);
    error ErrorComponentServiceNotComponent(address component);
    error ErrorComponentServiceTypeNotSupported(address component, ObjectType invalidType);
    error ErrorComponentServiceInvalidType(address component, ObjectType requiredType, ObjectType componentType);
    error ErrorComponentServiceAlreadyRegistered(address component);
    error ErrorComponentServiceReleaseMismatch(address component, VersionPart componentRelease, VersionPart parentRelease);
    error ErrorComponentServiceSenderNotComponentParent(NftId senderNftId, NftId compnentParentNftId);
    error ErrorComponentServiceParentNotInstance(NftId nftId, ObjectType objectType);
    error ErrorComponentServiceParentNotProduct(NftId nftId, ObjectType objectType);

    error ErrorProductServiceNoDistributionExpected(NftId productNftId);
    error ErrorProductServiceDistributionAlreadyRegistered(NftId productNftId, NftId distributionNftId);
    error ErrorProductServiceNoOraclesExpected(NftId productNftId);
    error ErrorProductServiceOraclesAlreadyRegistered(NftId productNftId, uint8 expectedOracles);
    error ErrorProductServicePoolAlreadyRegistered(NftId productNftId, NftId poolNftId);

    error ErrorComponentServiceNewWalletAddressZero();
    error ErrorComponentServiceWalletAddressZero();
    error ErrorComponentServiceWalletAddressIsSameAsCurrent();

    error ErrorComponentServiceWithdrawAmountIsZero();
    error ErrorComponentServiceWithdrawAmountExceedsLimit(Amount withdrawnAmount, Amount withdrawLimit);
    error ErrorComponentServiceWalletAllowanceTooSmall(address wallet, address spender, uint256 allowance, uint256 amount);

    event LogComponentServiceRegistered(NftId instanceNftId, NftId componentNftId, ObjectType componentType, address component, address token, address initialOwner); 
    event LogComponentServiceWalletAddressChanged(NftId componentNftId, address currentWallet, address newWallet);
    event LogComponentWalletTokensTransferred(address from, address to, uint256 amount);
    event LogComponentServiceComponentFeesWithdrawn(NftId componentNftId, address recipient, address token, Amount withdrawnAmount);
    event LogComponentServiceProductFeesUpdated(NftId productNftId);
    event LogComponentServiceDistributionFeesUpdated(NftId distributionNftId);
    event LogComponentServicePoolFeesUpdated(NftId poolNftId);
    event LogComponentServiceUpdateFee(
        NftId nftId, 
        string feeName, 
        UFixed previousFractionalFee, 
        uint256 previousFixedFee,
        UFixed newFractionalFee, 
        uint256 newFixedFee
    );

    //-------- component ----------------------------------------------------//

    /// @dev sets the components associated wallet address
    function setWallet(address newWallet) external;

    /// @dev locks the component associated with the caller
    function lock() external;

    /// @dev unlocks the component associated with the caller
    function unlock() external;

    /// @dev Withdraw fees from the distribution component. Only component owner is allowed to withdraw fees.
    /// @param withdrawAmount the amount to withdraw
    /// @return withdrawnAmount the amount that was actually withdrawn
    function withdrawFees(Amount withdrawAmount) external returns (Amount withdrawnAmount);

    /// @dev Registers the provided component with the product (sender)
    function registerComponent(address component) external returns (NftId componentNftId);

    //-------- product ------------------------------------------------------//

    /// @dev Registers the specified product component for the instance (sender)
    function registerProduct(address product) external returns (NftId productNftId);

    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    ) external;

    function increaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;
    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;

    //-------- distribution -------------------------------------------------//

    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    ) external;

    function increaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;

    //-------- distributor --------------------------------------------------//
    function increaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;

    //-------- pool ---------------------------------------------------------//

    function setPoolFees(
        Fee memory poolFee, // pool fee on net premium
        Fee memory stakingFee, // pool fee on staked capital from investor
        Fee memory performanceFee // pool fee on profits from capital investors
    ) external;

    function increasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;
    function decreasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;

    //-------- bundle -------------------------------------------------------//
    function increaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;
    function decreaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;

}