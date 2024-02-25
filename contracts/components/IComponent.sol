// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../types/NftId.sol";

interface IComponent is IRegisterable {

    error ErrorComponentProductNftAlreadySet();
    error ErrorComponentWalletAddressIsSameAsCurrent(address newWallet);
    error ErrorComponentWalletAllowanceTooSmall(address oldWallet, address newWallet, uint256 allowance, uint256 balance);
    error ErrorComponentUnauthorized(address caller, uint64 requiredRoleIdNum);
    error ErrorComponentNotProductService(address caller);

    event LogComponentWalletAddressChanged(address newWallet);
    event LogComponentWalletTokensTransferred(address from, address to, uint256 amount);

    function getName() external pure returns (string memory name);

    // TODO remove and replace with accessmanaged target locking mechanism
    function lock() external;
    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function setWallet(address walletAddress) external;
    function getWallet() external view returns (address walletAddress);

    function getInstance() external view returns (IInstance instance);

    function setProductNftId(NftId productNftId) external;
    function getProductNftId() external view returns (NftId productNftId);

}