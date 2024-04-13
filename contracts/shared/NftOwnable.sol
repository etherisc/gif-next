// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165} from "./ERC165.sol";
import {INftOwnable} from "./INftOwnable.sol";
import {NftId} from "../type/NftId.sol";
import {RegistryLinked} from "./RegistryLinked.sol";

contract NftOwnable is
    ERC165,
    RegistryLinked,
    INftOwnable
{
    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.NftOwnable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant NFT_OWNABLE_STORAGE_LOCATION_V1 = 0x07ebcf49758b6ed3af50fa146bec0abe157c0218fe65dc0874c286e9d5da4f00;

    struct NftOwnableStorage {
        NftId _nftId;
        address _initialOwner; 
    }

    /// @dev enforces msg.sender is owner of nft (or initial owner of nft ownable)
    modifier onlyOwner() {
        if (msg.sender != getOwner()) {
            revert ErrorNftOwnableNotOwner(msg.sender);
        }
        _;
    }


    /// @dev initialization for upgradable contracts
    // used in _initializeRegisterable
    function initializeNftOwnable(
        address initialOwner,
        address registryAddress
    )
        public
        virtual
        onlyInitializing()
    {
        initializeRegistryLinked(registryAddress);
        initializeERC165();

        if(initialOwner == address(0)) {
            revert ErrorNftOwnableInitialOwnerZero();
        }

        _getNftOwnableStorage()._initialOwner = initialOwner;
    }


    /// @dev links this contract to nft after registration
    // needs to be done once per registered contract and 
    // reduces registry calls to check ownership
    // does not need any protection as function can only do the "right thing"
    function linkToRegisteredNftId()
        public
        virtual
    {
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            revert ErrorNftOwnableAlreadyLinked($._nftId);
        }

        address contractAddress = address(this);

        if (!getRegistry().isRegistered(contractAddress)) {
            revert ErrorNftOwnableContractNotRegistered(contractAddress);
        }

        $._nftId = getRegistry().getNftId(contractAddress);
    }

    function getNftId() public view virtual override returns (NftId) {
        return _getNftOwnableStorage()._nftId;
    }

    function getOwner() public view virtual override returns (address) {
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            return getRegistry().ownerOf($._nftId);
        }

        return $._initialOwner;
    }

    /// @dev used in constructor of registry service manager
    // links ownership of registry service manager ot nft owner of registry service
    function _linkToNftOwnable(
        address nftOwnableAddress
    )
        internal
        returns (NftId)
    {
        NftOwnableStorage storage $ = _getNftOwnableStorage();

        if ($._nftId.gtz()) {
            revert ErrorNftOwnableAlreadyLinked($._nftId);
        }

        if (!getRegistry().isRegistered(nftOwnableAddress)) {
            revert ErrorNftOwnableContractNotRegistered(nftOwnableAddress);
        }

        $._nftId = getRegistry().getNftId(nftOwnableAddress);

        return $._nftId;
    }


    function _getNftOwnableStorage() private pure returns (NftOwnableStorage storage $) {
        assembly {
            $.slot := NFT_OWNABLE_STORAGE_LOCATION_V1
        }
    }
}