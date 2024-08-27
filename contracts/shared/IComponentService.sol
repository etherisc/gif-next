// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
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
    error ErrorComponentServiceTokenInvalid(address token);

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

    error ErrorComponentServiceNotRegistered(address instanceAddress);
    error ErrorComponentServiceNotInstance(address instanceAddress, ObjectType objectType);
    error ErrorComponentServiceInstanceVersionMismatch(address instanceAddress, VersionPart instanceVersion);
    
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
    event LogComponentServiceWalletTokensTransferred(NftId componentNftId, address currentWallet, address newWallet, uint256 currentBalance);
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

    /// @dev Approves the callers token handler to spend up to the specified amount of tokens.
    /// Reverts if the component's token handler wallet is not the token handler itself.
    function approveTokenHandler(IERC20Metadata token, Amount amount) external;

    /// @dev Sets the components associated wallet address.
    /// To set the wallet to the token handler contract, use address(0) as the new wallet adress.
    function setWallet(address newWallet) external;

    /// @dev Locks/Unlocks the calling component.
    function setLocked(bool locked) external;

    /// @dev Withdraw fees from the distribution component. Only component owner is allowed to withdraw fees.
    /// @param withdrawAmount the amount to withdraw
    /// @return withdrawnAmount the amount that was actually withdrawn
    function withdrawFees(Amount withdrawAmount) external returns (Amount withdrawnAmount);

    /// @dev Registers the provided component with the product (sender)
    function registerComponent(address component) external returns (NftId componentNftId);

    //-------- product ------------------------------------------------------//

    /// @dev Registers the specified product component for the instance (sender)
    function registerProduct(address product, address token) external returns (NftId productNftId);

    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    ) external;

    //-------- distribution -------------------------------------------------//

    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    ) external;

    //-------- pool ---------------------------------------------------------//

    function setPoolFees(
        Fee memory poolFee, // pool fee on net premium
        Fee memory stakingFee, // pool fee on staked capital from investor
        Fee memory performanceFee // pool fee on profits from capital investors
    ) external;

}