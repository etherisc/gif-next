// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "./NftId.sol";

/// @dev Target: Cover chain IDs up to 26 decimal places.
/// Current longest chain ID seems to be DCHAIN Testnet: 2713017997578000 with 16 decimal places 
type ChainId is uint96;

using {
    eqChainId as ==,
    neChainId as !=,
    ChainIdLib.toInt,
    ChainIdLib.eqz,
    ChainIdLib.gtz
} for ChainId global;


/// @dev return true if ChainId a is equal to ChainId b
function eqChainId(ChainId a, ChainId b) pure returns (bool) {
    return ChainId.unwrap(a) == ChainId.unwrap(b);
}

/// @dev return true if ChainId a is not equal to ChainId b
function neChainId(ChainId a, ChainId b) pure returns (bool) {
    return ChainId.unwrap(a) != ChainId.unwrap(b);
}


library ChainIdLib {

    error ErrorChainIdLibValueTooBig(uint256 chainId);


    function zero() public pure returns (ChainId) {
        return ChainId.wrap(0);
    }


    function max() public pure returns (ChainId) {
        return ChainId.wrap(_max());
    }


    function current() public view returns (ChainId) {
        return toChainId(block.chainid);
    }


    /// @dev return true iff chainId is 0
    function eqz(ChainId chainId) public pure returns (bool) {
        return ChainId.unwrap(chainId) == 0;
    }


    /// @dev return true iff chainId is > 0
    function gtz(ChainId chainId) public pure returns (bool) {
        return ChainId.unwrap(chainId) > 0;
    }


    /// @dev converts the uint into ChainId
    /// function reverts if value is exceeding max ChainId value
    function toChainId(uint256 chainId) public pure returns (ChainId) {
        if(chainId > _max()) {
            revert ErrorChainIdLibValueTooBig(chainId);
        }

        return ChainId.wrap(uint96(chainId));
    }


    function fromNftId(NftId nftId) public pure returns (ChainId) {
        uint256 nftIdInt = nftId.toInt();
        uint256 chainIdDigits = nftIdInt % 100; // Extract the last two digits
        uint256 chainIdInt = nftIdInt % 10**(chainIdDigits + 2) / 100; // Extract the chainId

        return toChainId(chainIdInt);
    }


    /// @dev converts the ChainId to a uint256
    function toInt(ChainId chainId) public pure returns (uint256) {
        return uint256(uint96(ChainId.unwrap(chainId)));
    }


    function _max() internal pure returns (uint96) {
        // IMPORTANT: type nees to match with actual definition for Amount
        return type(uint96).max;
    }
}