// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IProductService} from "../product/IProductService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {UFixed} from "../type/UFixed.sol";

/// @dev component base class
/// component examples are staking, product, distribution, pool and oracle
interface IComponentService is 
    IService
{
    error ErrorComponentServiceNewWalletAddressZero();
    error ErrorComponentServiceWalletAddressZero();
    error ErrorComponentServiceWalletAddressIsSameAsCurrent();

    error ErrorComponentServiceWithdrawAmountIsZero();
    error ErrorComponentServiceWithdrawAmountExceedsLimit(Amount withdrawnAmount, Amount withdrawLimit);
    error ErrorComponentServiceWalletAllowanceTooSmall(address wallet, address spender, uint256 allowance, uint256 amount);

    event LogComponentServiceWalletAddressChanged(NftId componentNftId, address currentWallet, address newWallet);
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
    function withdrawFees(Amount withdrawAmount) external returns (Amount withdrawnAmount);

    //-------- product ------------------------------------------------------//

    /// @dev registers the sending component as a product component
    function registerProduct() external;

    function setProductFees(
        Fee memory productFee, // product fee on net premium
        Fee memory processingFee // product fee on payout amounts        
    ) external;

    function increaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;
    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;

    //-------- distribution -------------------------------------------------//

    /// @dev registers the sending component as a distribution component
    function registerDistribution() external;

    function setDistributionFees(
        Fee memory distributionFee, // distribution fee for sales that do not include commissions
        Fee memory minDistributionOwnerFee // min fee required by distribution owner (not including commissions for distributors)
    ) external;

    function increaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;

    //-------- oracle -------------------------------------------------------//

    /// @dev registers the sending component as an oracle component
    function registerOracle() external;

    //-------- pool ---------------------------------------------------------//

    /// @dev registers the sending component as a pool component
    function registerPool() external;

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