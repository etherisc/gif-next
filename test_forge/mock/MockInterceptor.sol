// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ITransferInterceptor} from "../../contracts/registry/ITransferInterceptor.sol";

contract MockInterceptor is ITransferInterceptor {

    event LogNftTransferIntercepted(address from, address to, uint256 tokenId);
    event LogNftMintIntercepted(address to, uint256 tokenId);

    function nftMint(address to, uint256 tokenId) external {
        emit LogNftMintIntercepted(to, tokenId);
    }

    function nftTransferFrom(address from, address to, uint256 tokenId) external {
        emit LogNftTransferIntercepted(from, to, tokenId);
    }
}
