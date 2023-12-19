// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin5/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IChainNft} from "./IChainNft.sol";
import {IRegistry} from "./IRegistry.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {NftId} from "../types/NftId.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {Registry} from "./Registry.sol";
import {RegistryService} from "./RegistryService.sol";


contract RegistryInstaller is
    Ownable,
    IERC721Receiver
{
    error ErrorProxyManagerWithZeroAddress();
    error ErrorRegistryServiceWithZeroAddress();
    error ErrorProxyManagerUnexpectedOwner(address expectedOwner, address actualOwner);
    error ErrorInstallerNotProxyManagerOwner(address installer, address actualOwner);

    ProxyManager private _proxyManager;
    address private _implementation;
    RegistryService private _registryService;
    IRegistry private _registry;
    IChainNft private _chainNft;

    /// @dev initializes proxy manager with registry service implementation and deploys registry
    constructor(
        address proxyManagerAddress, 
        address registryServiceImplementationAddress
    )
        Ownable(msg.sender)
    {
        if (proxyManagerAddress == address(0)) { revert ErrorProxyManagerWithZeroAddress(); }
        if (registryServiceImplementationAddress == address(0)) { revert ErrorRegistryServiceWithZeroAddress(); }

        _proxyManager = ProxyManager(proxyManagerAddress);
        // check proxy manager owner is owner of installer
        if (_proxyManager.owner() != owner()) { revert ErrorProxyManagerUnexpectedOwner(_proxyManager.owner(), owner()); }

        _implementation = registryServiceImplementationAddress;
    }

    function installRegistryServiceWithRegistry()
        external
        onlyOwner()
    {
        // check that this contract is now proxy manager owner
        if (_proxyManager.owner() != address(this)) { revert ErrorInstallerNotProxyManagerOwner(address(this), _proxyManager.owner()); }

        IVersionable versionable = _proxyManager.deploy(_implementation, type(Registry).creationCode);
        _registryService = RegistryService(address(versionable));
        _registry = _registryService.getRegistry();
        _chainNft = _registry.getChainNft();

        // transfer registry ownership back to owner
        NftId registryNftId = _registry.getNftId(address(_registry));
        _chainNft.safeTransferFrom(
            address(this),
            owner(),
            registryNftId.toInt(),
            "");

        // transfer proxy manager back to owner
        _proxyManager.transferOwnership(owner());
    }

    function getRegistryService()
        external
        view
        returns (RegistryService registryService)
    {
        return _registryService;
    }

    function getRegistry()
        external
        view
        returns (RegistryService registryService)
    {
        return _registryService;
    }

    //--- IERC721Receiver -----------------------------------//
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external 
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
