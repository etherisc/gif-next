// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {InitializableERC165} from "./InitializableERC165.sol";
import {INftOwnable} from "./INftOwnable.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RegistryLinked} from "./RegistryLinked.sol";

contract NftOwnable is
    InitializableERC165,
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

    modifier onlyNftOwner(NftId nftId) {
        if(!getRegistry().isOwnerOf(nftId, msg.sender)) {
            revert ErrorNftOwnableNotOwner(msg.sender);
        }
        _;
    }

    modifier onlyNftOfType(NftId nftId, ObjectType expectedObjectType) {
        _checkNftType(nftId, expectedObjectType);
        _;
    }

    function _checkNftType(NftId nftId, ObjectType expectedObjectType) internal view {
        assert(expectedObjectType.gtz()); // TODO must not check non registered nftId against empty type!
        if(!getRegistry().isObjectType(nftId, expectedObjectType)) {
            revert ErrorNftOwnableInvalidType(nftId, expectedObjectType);
        }
    }


    /// @dev Initialization for upgradable contracts.
    // used in __Registerable_init, ProxyManager._preDeployChecksAndSetup
    function __NftOwnable_init(
        address registry,
        address initialOwner
    )
        internal
        virtual
        onlyInitializing()
    {
        __RegistryLinked_init(registry);
        _initializeERC165();

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
        returns (NftId nftId)
    {
        return _linkToNftOwnable(address(this));
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

        $._nftId = getRegistry().getNftIdForAddress(nftOwnableAddress);

        return $._nftId;
    }


    function _getNftOwnableStorage() private pure returns (NftOwnableStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := NFT_OWNABLE_STORAGE_LOCATION_V1
        }
    }
}