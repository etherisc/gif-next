// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IComponents} from "../instance/module/IComponents.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

/// @dev component base class
/// component examples are product, distribution, pool and oracle
interface IComponent is 
    IRegisterable,
    ITransferInterceptor
{
    error ErrorComponentNotChainNft(address caller);
    error ErrorComponentNotProductService(address caller);
    error ErrorComponentNotInstance(NftId instanceNftId);
    error ErrorComponentProductNftAlreadySet();

    error ErrorComponentWalletAddressZero();
    error ErrorComponentWalletAddressIsSameAsCurrent();
    error ErrorComponentWalletAllowanceTooSmall(address oldWallet, address newWallet, uint256 allowance, uint256 balance);

    event LogComponentWalletAddressChanged(address oldWallet, address newWallet);
    event LogComponentWalletTokensTransferred(address from, address to, uint256 amount);

    /// @dev locks component to disable functions that may change state related to this component, the only exception is function "unlock"
    /// only component owner (nft holder) is authorizes to call this function
    function lock() external;

    /// @dev unlocks component to (re-)enable functions that may change state related to this component
    /// only component owner (nft holder) is authorizes to call this function
    function unlock() external;

    /// @dev sets the wallet address for the component
    /// if the current wallet has tokens, these will be transferred
    /// if the new wallet address is externally owned, an approval from the 
    /// owner of the external wallet for the component to move all tokens must exist
    function setWallet(address walletAddress) external;

    /// @dev only product service may set product nft id during registration of product setup
    function setProductNftId(NftId productNftId) external;

    /// @dev returns the name of this component
    /// to successfully register the component with an instance the name MUST be unique in the linked instance
    function getName() external view returns (string memory name);

    /// @dev defines which ERC20 token is used by this component
    function getToken() external view returns (IERC20Metadata token);

    /// @dev defines the instance to which this component is linked to
    function getInstance() external view returns (IInstance instance);

    /// @dev defines the wallet address used to hold the ERC20 tokens related to this component
    /// the default address is the component token address
    function getWallet() external view returns (address walletAddress);

    /// @dev defines the product to which this component is linked to
    /// this is only relevant for pool and distribution components
    function getProductNftId() external view returns (NftId productNftId);

    function isNftInterceptor() external view returns(bool isInterceptor);

    /// @dev returns component infos for this pool
    /// when registered with an instance the info is obtained from the data stored in the instance
    /// when not registered the function returns the info from the component contract
    function getComponentInfo() external view returns (IComponents.ComponentInfo memory info);
}