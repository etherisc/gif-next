// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IRegistry} from "./IRegistry.sol";
import {VersionPart} from "../type/Version.sol";
import {REGISTRY} from "../type/ObjectType.sol";
import {NftOwnable} from "../shared/NftOwnable.sol";

/// @title contract to register token per GIF major release.
contract TokenRegistry is
    NftOwnable
{
    event LogRegistered(address token, string symbol, uint256 decimals);
    event LogTokenStateSet(address token, VersionPart majorVersion, bool active);

    error NotContract(address account);
    error NotToken(address account);
    error TokenDecimalsZero();
    error TokenMajorVersionInvalid(VersionPart majorVersion);

    address [] internal _token;
    mapping(address token => bool registered) internal _registered;
    mapping(address token => mapping(VersionPart majorVersion => bool isActive)) internal _active;

    constructor(
        address registry
    )
    { 
        initialize(registry);
    }

    function initialize(address registry)
        public
        initializer()
    {
        initializeNftOwnable(msg.sender, registry);
    }


    /// @dev link ownership of token registry to nft owner of registry service
    // TODO see linkToProxy() in ProxyManager, implement similar, decide which nft token registry must be linked to 
    // TODO latter registry service will get new release, new address, new nft, TokenRegistry will not catch that -> use AccessManaged only for services
    /*
    function linkToNftOwnable(address registryAddress) 
        external
        onlyOwner
    {
        IRegistry registry = IRegistry(registryAddress);
        address registryServiceAddress = registry.getServiceAddress(REGISTRY(), registry.getNextVersion());

        _linkToNftOwnable(registryServiceAddress);
    }
    */

    /// @dev token state is informative, registry have no clue about used tokens
    // component owner is responsible for token selection and operations
    // service MUST deny registration of component with inactive token 
    function setActive(address token, VersionPart majorVersion, bool active)
        external
        onlyOwner
    {
        // verify that token is registered
        if (!_registered[token]) {
            _registerToken(token);
        }

        // verify valid major version
        // ensure major version increments is one
        uint256 version = majorVersion.toInt();
        if (!getRegistry().isActiveRelease(majorVersion)) {
            revert TokenMajorVersionInvalid(majorVersion);
        }

        _active[token][majorVersion] = active;

        emit LogTokenStateSet(token, majorVersion, active);
    }

    function tokens() external view returns (uint256) {
        return _token.length;
    }

    function getToken(uint256 idx) external view returns (IERC20Metadata token) {
        return IERC20Metadata(_token[idx]);
    }

    function isRegistered(address token) external view returns (bool) {
        return _registered[token];
    }

    function isActive(address token, VersionPart majorVersion) external view returns (bool) {
        return _active[token][majorVersion];
    }

    /// @dev some sanity checks to prevent unintended registration
    function _registerToken(address token) internal {

        // MUST be contract
        if(token.code.length == 0) {
            revert NotContract(token);
        }

        // MUST have decimals > 0 (indicator that this is in fact an erc20 token)
        IERC20Metadata erc20 = IERC20Metadata(token);
        if(erc20.decimals() == 0) {
            revert TokenDecimalsZero();
        }

        _registered[token] = true;
        _token.push(token);

        emit LogRegistered(token, erc20.symbol(), erc20.decimals());
    }
}
