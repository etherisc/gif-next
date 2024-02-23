// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IInstance} from "../instance/IInstance.sol";
import {NftId} from "../types/NftId.sol";

interface IBaseComponent is IRegisterable {
    error ErrorBaseComponentWalletAddressIsSameAsCurrent(address newWallet);
    error ErrorBaseComponentWalletAllowanceTooSmall(address oldWallet, address newWallet, uint256 allowance, uint256 balance);
    error ErrorBaseComponentUnauthorized(address caller, uint64 requiredRoleIdNum);

    event LogBaseComponentWalletAddressChanged(address newWallet);
    event LogBaseComponentWalletTokensTransferred(address from, address to, uint256 amount);

    function getName() external pure returns (string memory name);

    function lock() external;

    function unlock() external;

    function getToken() external view returns (IERC20Metadata token);

    function setWallet(address walletAddress) external;
    function getWallet() external view returns (address walletAddress);

    function getInstance() external view returns (IInstance instance);

    function setProductNftId(NftId productNftId) external;
    function getProductNftId() external view returns (NftId productNftId);

}