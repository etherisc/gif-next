// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {ERC165} from "./ERC165.sol";
import {IPolicyHolder} from "./IPolicyHolder.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../types/NftId.sol";
import {NumberId} from "../types/NumberId.sol";

contract PolicyHolder is
    ERC165,
    Initializable,
    IPolicyHolder
{

    /// @dev empty default implementation
    function policyCreated(NftId policyNftId) external virtual { }

    /// @dev empty default implementation
    function payoutProcessed(NftId policyNftId, NumberId payoutId, address beneficiary, uint256 amount) external virtual { }

    /// @dev determines beneficiary address that will be used in payouts targeting this contract
    /// returned address will override GIF default where the policy nft holder is treated as beneficiary
    function getBeneficiary(NftId policyId, NumberId claimId) external virtual view returns (address beneficiary) { 
        // TODO add implementation
    }

    //--- IERC165 functions ---------------// 
    function onERC721Received(
        address, // operator
        address, // from
        uint256, // tokenId
        bytes calldata // data
    )
        external
        virtual
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _setBeneficiary(address beneficiary) internal {

    }

    function _setBeneficiary(NftId policyId, address beneficiary) internal {

    }
}