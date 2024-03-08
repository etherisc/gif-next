// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IInstance} from "../instance/IInstance.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";

interface IComponent is 
    IRegisterable,
    ITransferInterceptor
{

    error ErrorComponentNotChainNft(address caller);
    error ErrorComponentNotProductService(address caller);
    error ErrorComponentNotInstance(NftId instanceNftId, address instance);
    error ErrorComponentProductNftAlreadySet();
    error ErrorComponentWalletAddressZero();
    error ErrorComponentWalletAddressIsSameAsCurrent(address newWallet);
    error ErrorComponentWalletAllowanceTooSmall(address oldWallet, address newWallet, uint256 allowance, uint256 balance);
    error ErrorComponentUnauthorized(address caller, uint64 requiredRoleIdNum);

    event LogComponentWalletAddressChanged(address newWallet);
    event LogComponentWalletTokensTransferred(address from, address to, uint256 amount);

    function getName() external view returns (string memory name);

    // TODO remove and replace with accessmanaged target locking mechanism
    function lock() external;
    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function setWallet(address walletAddress) external;
    function getWallet() external view returns (address walletAddress);

    function isNftInterceptor() external view returns(bool isInterceptor);

    function getInstance() external view returns (IInstance instance);

    /// @dev returns the service address for the specified domain
    /// gets address via lookup from registry using the major version form the linked instance
    function getServiceAddress(ObjectType domain) external view returns (address service);

    function setProductNftId(NftId productNftId) external;
    function getProductNftId() external view returns (NftId productNftId);

    function getInstanceService() external view returns (IInstanceService);
    function getProductService() external view returns (IProductService);
}