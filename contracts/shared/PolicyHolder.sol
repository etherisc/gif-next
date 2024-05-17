// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ERC165} from "./ERC165.sol";
import {IPolicyHolder} from "./IPolicyHolder.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId, PayoutIdLib} from "../type/PayoutId.sol";
import {RegistryLinked} from "./RegistryLinked.sol";
import {IRegistry} from "../registry/IRegistry.sol";

/// @dev template implementation for IPolicyHolder
contract PolicyHolder is
    ERC165,
    RegistryLinked, // TODO need upgradeable version
    IPolicyHolder
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.PolicyHolder")) - 1)) & ~bytes32(uint256(0xff));
    // TODO fix address
    bytes32 public constant POLICY_HOLDER_STORAGE_LOCATION_V1 = 0x07ebcf49758b6ed3af50fa146bec0abe157c0218fe65dc0874c286e9d5da4f00;

    struct PolicyHolderStorage {
        mapping(NftId policyId => mapping(PayoutId payoutId => address beneficiary)) _beneficiary;
        address _beneficiaryDefault;
    }

    function initializePolicyHolder(
        address registryAddress,
        address beneficiaryDefault
    )
        public
        virtual
        onlyInitializing()
    {
        initializeRegistryLinked(registryAddress);

        _getPolicyHolderStorage()._beneficiaryDefault = beneficiaryDefault;

        registerInterface(type(IPolicyHolder).interfaceId);
    }

    /// @dev empty default implementation
    function requestPayout(NftId requestingPolicyNftId, Amount requestedPayoutAmount) external { }

    /// @dev empty default implementation
    function policyActivated(NftId policyNftId) external {}

    /// @dev empty default implementation
    function policyExpired(NftId policyNftId) external {}

    /// @dev empty default implementation
    function claimConfirmed(NftId policyNftId, ClaimId claimId, Amount amount) external {}

    /// @dev empty default implementation
    function payoutExecuted(NftId policyNftId, PayoutId payoutId, address beneficiary, Amount amount) external {}

    /// @dev returns payout specific beneficiary
    /// when no such beneficiary is defined the policy specific beneficiary is returned
    function getBeneficiary(NftId policyNftId, PayoutId payoutId) external virtual view returns (address beneficiary) {
        beneficiary = _getPolicyHolderStorage()._beneficiary[policyNftId][payoutId];

        // fallback to claim independent beneficiary
        if(beneficiary == address(0) && payoutId.gtz()) {
            beneficiary = _getPolicyHolderStorage()._beneficiary[policyNftId][PayoutIdLib.zero()];
        }
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

    /// @dev sets policy specific beneficiary (used when no payout specific beneficiary is defined)
    function _setBeneficiary(NftId policyNftId, address beneficiary) internal {
        _setBeneficiary(policyNftId, PayoutIdLib.zero(), beneficiary);
    }

    /// @dev sets policy and claim specific beneficiary
    function _setBeneficiary(NftId policyNftId, PayoutId payoutId, address beneficiary) internal {
        _getPolicyHolderStorage()._beneficiary[policyNftId][payoutId] = beneficiary;
    }

    function _getPolicyHolderStorage() private pure returns (PolicyHolderStorage storage $) {
        assembly {
            $.slot := POLICY_HOLDER_STORAGE_LOCATION_V1
        }
    }
}