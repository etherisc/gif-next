// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";

/// @dev component base class
/// component examples are staking, product, distribution, pool and oracle
interface IComponent is 
    IAccessManaged,
    IRegisterable,
    ITransferInterceptor
{
    error ErrorComponentNotChainNft(address caller);

    error ErrorComponentTokenAddressZero();
    error ErrorComponentNameLengthZero();
    error ErrorComponentWalletAddressZero();
    error ErrorComponentWalletAddressIsSameAsCurrent();
    error ErrorComponentWalletAllowanceTooSmall(address oldWallet, address newWallet, uint256 allowance, uint256 balance);
    error ErrorComponentWalletNotComponent();

    event LogComponentWalletAddressChanged(address oldWallet, address newWallet);
    event LogComponentWalletTokensTransferred(address from, address to, uint256 amount);
    event LogComponentTokenHandlerApproved(address token, Amount limit);

    /// @dev approves token hanlder to spend up to the specified amount of tokens
    /// reverts if component wallet is not component itself
    /// only component owner (nft holder) is authorizes to call this function
    function approveTokenHandler(Amount spendingLimitAmount) external;

    /// @dev sets the wallet address for the component
    /// if the current wallet has tokens, these will be transferred
    /// if the new wallet address is externally owned, an approval from the 
    /// owner of the external wallet for the component to move all tokens must exist
    function setWallet(address walletAddress) external;

    /// @dev returns the name of this component
    /// to successfully register the component with an instance the name MUST be unique in the linked instance
    function getName() external view returns (string memory name);

    /// @dev defines which ERC20 token is used by this component
    function getToken() external view returns (IERC20Metadata token);

    /// @dev returns token handler for this component
    function getTokenHandler() external view returns (TokenHandler tokenHandler);

    /// @dev defines the wallet address used to hold the ERC20 tokens related to this component
    /// the default address is the component token address
    function getWallet() external view returns (address walletAddress);

    /// @dev returns true iff this compoent intercepts nft minting and transfers for objects registered by this component
    function isNftInterceptor() external view returns(bool isInterceptor);

    /// @dev returns true iff this component is registered with the registry
    function isRegistered() external view returns (bool);

    /// @dev returns the component infos for this component
    /// for a non registered component the function returns getInitialComponentInfo()
    function getComponentInfo() external view returns (IComponents.ComponentInfo memory info);

    /// @dev returns the iniital component infos for this component
    function getInitialComponentInfo() external view returns (IComponents.ComponentInfo memory info);
}