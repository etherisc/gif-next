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
    event LogTokenRegistryTokenRegistered(uint256 chainId, address token, uint256 decimals, string symbol);
    event LogTokenRegistryTokenStateSet(uint256 chainId, address token, VersionPart majorVersion, bool active);

    error ErrorTokenRegistryTokenAlreadyRegistered(uint256 chainId, address token);
    error ErrorTokenRegistryTokenNotContract(uint256 chainId, address token);
    error ErrorTokenRegistryTokenNotErc20(uint256 chainId, address token);

    error ErrorTokenRegistryTokenNotRegistered(uint256 chainId, address token);
    error ErrorTokenRegistryMajorVersionInvalid(VersionPart majorVersion);

    struct TokenInfo {
        uint256 chainId;
        address token;
        uint8 decimals;
        string symbol;
    }

    TokenInfo [] internal _token;
    mapping(uint256 chainId => mapping(address token => bool registered)) internal _registered;
    mapping(uint256 chainId => mapping(address token => mapping(VersionPart majorVersion => bool isActive))) internal _active;

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
    function linkToRegistryService() 
        external
    {
        IRegistry registry = getRegistry();
        address registryServiceAddress = registry.getServiceAddress(REGISTRY(), registry.getNextVersion());

        _linkToNftOwnable(registryServiceAddress);
    }


    function registerToken(address token)
        external
        onlyOwner
    {
        uint256 chainId = block.chainid;

        if (_registered[chainId][token]) {
            revert ErrorTokenRegistryTokenAlreadyRegistered(chainId, token);
        }

        // MUST be contract
        if(token.code.length == 0) {
            revert ErrorTokenRegistryTokenNotContract(chainId, token);
        }

        // MUST have decimals > 0 (indicator that this is in fact an erc20 token)
        IERC20Metadata erc20 = IERC20Metadata(token);
        if(!_implementsErc20Functions(erc20)) {
            revert ErrorTokenRegistryTokenNotErc20(chainId, token);
        }

        _registerToken(chainId, token, erc20.decimals(), erc20.symbol());
    }


    /// @dev token state is informative, registry have no clue about used tokens
    // component owner is responsible for token selection and operations
    // service MUST deny registration of component with inactive token 
    function setActive(
        uint256 chainId, 
        address token, 
        VersionPart majorVersion, 
        bool active
    )
        external
        onlyOwner
    {
        setActiveWithVersionCheck(chainId, token, majorVersion, active, true);
    }


    function setActiveWithVersionCheck(
        uint256 chainId, 
        address token, 
        VersionPart majorVersion, 
        bool active,
        bool enforceVersionCheck
    )
        public
        onlyOwner
    {
        // verify that token is registered
        if (!_registered[chainId][token]) {
            revert ErrorTokenRegistryTokenNotRegistered(chainId, token);
        }

        // verify valid major version
        if(enforceVersionCheck) {
            uint256 version = majorVersion.toInt();
            if (!getRegistry().isValidRelease(majorVersion)) {
                revert ErrorTokenRegistryMajorVersionInvalid(majorVersion);
            }
        }

        _active[chainId][token][majorVersion] = active;

        emit LogTokenRegistryTokenStateSet(chainId, token, majorVersion, active);
    }

    function tokens() external view returns (uint256) {
        return _token.length;
    }

    function getToken(uint256 idx) external view returns (TokenInfo memory tokenInfo) {
        return _token[idx];
    }

    function isRegistered(uint256 chainId, address token) external view returns (bool) {
        return _registered[chainId][token];
    }

    function isActive(uint256 chainId, address token, VersionPart majorVersion) external view returns (bool) {
        return _active[chainId][token][majorVersion];
    }

    /// @dev checks availability of non-optional view functions
    /// https://eips.ethereum.org/EIPS/eip-20#methods
    function _implementsErc20Functions(IERC20Metadata token) internal view returns (bool implementsErc20Functions) {
        try token.totalSupply() returns (uint256) {
            // so far so goood
        } catch {
            return false;
        }

        try token.balanceOf(address(1)) returns (uint256) {
            // so far so goood
        } catch {
            return false;
        }

        try token.allowance(address(1), address(2)) returns (uint256) {
            // so far so goood
        } catch {
            return false;
        }

        return true;
    }

    /// @dev some sanity checks to prevent unintended registration
    function _registerToken(uint256 chainId, address token, uint8 decimals, string memory symbol) internal {

        _registered[chainId][token] = true;
        _token.push(
            TokenInfo({
            chainId: chainId,
            token: token,
            decimals: decimals,
            symbol: symbol})
        );

        emit LogTokenRegistryTokenRegistered(chainId, token, decimals, symbol);
    }
}
