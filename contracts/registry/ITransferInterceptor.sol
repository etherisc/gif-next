// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ITransferInterceptor {
    function nftTransferFrom(address from, address to, uint256 tokenId) external;
}