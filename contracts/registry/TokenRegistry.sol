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
    event LogTokenRegistryTokenGlobalStateSet(uint256 chainId, address token, bool active);
    event LogTokenRegistryTokenStateSet(uint256 chainId, address token, VersionPart majorVersion, bool active);

    error ErrorTokenRegistryChainIdZero();
    error ErrorTokenRegistryTokenAddressZero();

    error ErrorTokenRegistryNotRemoteToken(uint256 chainId, address token);
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
        bool active;
    }

    TokenInfo [] internal _token;
    mapping(uint256 chainId => mapping(address token => TokenInfo info)) internal _tokenInfo;
    mapping(uint256 chainId => mapping(address token => mapping(VersionPart majorVersion => bool isActive))) internal _active;

    /// @dev enforces msg.sender is owner of nft (or initial owner of nft ownable)
    modifier onlyRegisteredToken(uint256 chainId, address token) {
        if (!isRegistered(chainId, token)) {
            revert ErrorTokenRegistryTokenNotRegistered(chainId, token);
        }
        _;
    }

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


    /// @dev register an onchain token.
    /// this function verifies that the provided token address is a contract that implements
    /// the non optional erc20 view functions.
    function registerToken(address token)
        external
        onlyOwner
    {
        uint256 chainId = block.chainid;

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


    /// @dev register the remote token with the provided attributes.
    /// this function may not be used for tokens when chainId == block.chainid.
    function registerRemoteToken(
        uint256 chainId,
        address token,
        uint8 decimals,
        string memory symbol
    )
        external
        onlyOwner
    {
        if (chainId == block.chainid) {
            revert ErrorTokenRegistryNotRemoteToken(chainId, token);
        }

        _registerToken(chainId, token, decimals, symbol);
    }


    /// @dev set active flag on token itself.
    /// when setting a token to active=false isActive will return false
    /// regardless of release specific active value.
    function setActive(
        uint256 chainId, 
        address token, 
        bool active
    )
        external
        onlyOwner
        onlyRegisteredToken(chainId, token)
    {
        _tokenInfo[chainId][token].active = active;
        emit LogTokenRegistryTokenGlobalStateSet(chainId, token, active);
    }


    /// @dev token state is informative, registry have no clue about used tokens
    // component owner is responsible for token selection and operations
    // service MUST deny registration of component with inactive token 
    function setActiveForVersion(
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
        onlyRegisteredToken(chainId, token)
    {
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

    /// @dev returns the number of registered tokens
    function tokens() external view returns (uint256) {
        return _token.length;
    }

    /// @dev returns the token info for the specified index position [0 .. tokens() - 1].
    function getTokenInfo(uint256 idx) external view returns (TokenInfo memory tokenInfo) {
        return _token[idx];
    }

    /// @dev returns the token info for the specified token coordinates.
    function getTokenInfo(uint256 chainId, address token) external view returns (TokenInfo memory tokenInfo) {
        return _tokenInfo[chainId][token];
    }

    /// @dev returns true iff the specified token has been registered for this TokenRegistry contract.
    function isRegistered(uint256 chainId, address token) public view returns (bool) {
        return _tokenInfo[chainId][token].chainId > 0;
    }

    /// @dev returns true iff both the token is active for the specfied version and the global token state is active
    function isActive(uint256 chainId, address token, VersionPart majorVersion) external view returns (bool) {
        if(!_tokenInfo[chainId][token].active) {
            return false;
        }

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

    /// @dev some sanity checks to prevent unintended registration:
    /// - token not yet registered
    /// - chainId not zero
    /// - token address not zero
    function _registerToken(uint256 chainId, address token, uint8 decimals, string memory symbol) internal {

        if (isRegistered(chainId, token)) {
            revert ErrorTokenRegistryTokenAlreadyRegistered(chainId, token);
        }

        if(chainId == 0) {
            revert ErrorTokenRegistryChainIdZero();
        }

        if(token == address(0)) {
            revert ErrorTokenRegistryTokenAddressZero();
        }

        TokenInfo memory tokenInfo = TokenInfo({
            chainId: chainId,
            token: token,
            decimals: decimals,
            symbol: symbol,
            active: true});

        _tokenInfo[chainId][token] = tokenInfo;
        _token.push(tokenInfo);

        emit LogTokenRegistryTokenRegistered(chainId, token, decimals, symbol);
    }
}
