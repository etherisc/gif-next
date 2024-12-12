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
    // registerProduct
    error ErrorComponentServiceCallerNotInstance(address caller);
    error ErrorComponentServiceNotProduct(address product);
    error ErrorComponentServiceTokenInvalid(address token);

    // registerComponent
    error ErrorComponentServiceCallerNotProduct(address caller);
    error ErrorComponentServiceNotComponent(address component);

    error ErrorComponentServiceNotInstanceLinkedComponent(address component);
    error ErrorComponentServiceComponentTypeNotSupported(address component, ObjectType invalid);
    error ErrorComponentServiceComponentParentInvalid(address component, NftId required, NftId actual);
    error ErrorComponentServiceComponentReleaseMismatch(address component, VersionPart serviceRelease, VersionPart componentRelease);
    error ErrorComponentServiceComponentAlreadyRegistered(address component);
    
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

    event LogComponentServiceComponentLocked(address indexed component, bool indexed locked);
    event LogComponentServiceTokenHandlerDeployed(NftId indexed componentNftId, address indexed tokenHandler, address indexed token);
    event LogComponentServiceRegistered(NftId indexed instanceNftId, NftId indexed componentNftId, ObjectType indexed componentType, address component, address token, address initialOwner); 
    event LogComponentServiceComponentFeesWithdrawn(NftId indexed componentNftId, address indexed recipient, Amount indexed withdrawnAmount, address token);
    event LogComponentServiceProductFeesUpdated(NftId indexed productNftId);
    event LogComponentServiceDistributionFeesUpdated(NftId indexed distributionNftId);
    event LogComponentServicePoolFeesUpdated(NftId indexed poolNftId);
    event LogComponentServiceUpdateFee(
        NftId indexed nftId, 
        string feeName, 
        UFixed previousFractionalFee, 
        Amount previousFixedFee,
        UFixed indexed newFractionalFee, 
        Amount indexed newFixedFee
    );
    event LogComponentServiceProductCreated(
        NftId indexed productNftId, address indexed productAddress, bool indexed hasDistribution, uint8 expectedNumberOfOracles);
    event LogComponentServiceProductInitialProductFeesSet(
        NftId indexed productNftId, 
        Amount indexed productFeeFixed, UFixed indexed productFeeFractional,
        Amount processingFeeFixed, UFixed processingFeeFractional);
    event LogComponentServiceProductInitialDistributionFeesSet(
        NftId indexed productNftId, 
        Amount indexed distributionFeeFixed, UFixed indexed distributionFeeFractional,
        Amount minDistributionOwnerFeeFixed, UFixed minDistributionOwnerFeeFractional);
    event LogComponentServiceProductInitialPoolFeesSet(
        NftId indexed productNftId, 
        Amount indexed poolFeeFixed, UFixed indexed poolFeeFractional,
        Amount stakingFeeFixed, UFixed stakingFeeFractional,
        Amount performanceFeeFixed, UFixed performanceFeeFractional);
    event LogComponentServicePoolCreated(
        NftId indexed poolNftId, NftId indexed productNftId, address indexed componentAddress, 
        Amount maxBalanceAmount, UFixed collateralizationLevel, UFixed retentionLevel, 
        bool isExternallyManaged, bool isVerifyingApplications);
    event LogComponentServiceDistributionCreated(
        NftId indexed distributionNftId, NftId indexed productNftId);
    event LogComponentServiceOracleCreated(
        NftId indexed oracleNftId, NftId indexed productNftId);
    
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