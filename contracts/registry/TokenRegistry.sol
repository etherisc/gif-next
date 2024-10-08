// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "./IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IStaking} from "../staking/IStaking.sol";

import {ChainId, ChainIdLib} from "../type/ChainId.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev The TokenRegistry contract is used to whitelist/manage ERC-20 of tokens per major release.
/// Only whitelisted tokens can be used as default tokens for products, distribution and pools components.
contract TokenRegistry is
    AccessManaged,
    IRegistryLinked
{
    event LogTokenRegistryTokenRegistered(ChainId chainId, address token, uint256 decimals, string symbol);
    event LogTokenRegistryTokenGlobalStateSet(ChainId chainId, address token, bool active);
    event LogTokenRegistryTokenStateSet(ChainId chainId, address token, VersionPart release, bool active);

    error ErrorTokenRegistryChainIdZero();
    error ErrorTokenRegistryTokenAddressZero();

    error ErrorTokenRegistryNotRemoteToken(ChainId chainId, address token);
    error ErrorTokenRegistryTokenAlreadyRegistered(ChainId chainId, address token);
    error ErrorTokenRegistryTokenNotContract(ChainId chainId, address token);
    error ErrorTokenRegistryTokenNotErc20(ChainId chainId, address token);

    error ErrorTokenRegistryTokenNotRegistered(ChainId chainId, address token);
    error ErrorTokenRegistryMajorVersionInvalid(VersionPart release);

    struct TokenInfo {
        // slot 0
        ChainId chainId; // 96
        address token; // 20
        uint8 decimals; // 8
        bool active;
        // slot 1
        string symbol;
    }

    mapping(ChainId chainId => mapping(address token => TokenInfo info)) internal _tokenInfo;
    mapping(ChainId chainId => mapping(address token => mapping(VersionPart release => bool isActive))) internal _active;
    TokenInfo [] internal _token;

    IRegistry internal _registry;
    ChainId internal _chainId = ChainIdLib.current();
    IERC20Metadata internal _dipToken;

    /// @dev enforces msg.sender is owner of nft (or initial owner of nft ownable)
    modifier onlyRegisteredToken(ChainId chainId, address token) {
        if (!isRegistered(chainId, token)) {
            revert ErrorTokenRegistryTokenNotRegistered(chainId, token);
        }
        _;
    }

    constructor(IRegistry registry, IERC20Metadata dipToken)
        AccessManaged(msg.sender)
    {
        // set authority
        address authority = RegistryAdmin(registry.getRegistryAdminAddress()).authority();
        setAuthority(authority);
        
        _registry = registry;

        // TODO deal with chains without a dip token
        _dipToken = _verifyOnchainToken(address(dipToken));

        // register dip token
        _registerToken(
            _chainId, 
            address(_dipToken), 
            _dipToken.decimals(), 
            _dipToken.symbol());
    }


    /// @dev register an onchain token.
    /// this function verifies that the provided token address is a contract that implements
    /// the non optional erc20 view functions.
    function registerToken(address tokenAddress)
        external
        restricted()
    {
        // checks
        IERC20Metadata token = _verifyOnchainToken(tokenAddress);

        // effects
        _registerToken(_chainId, tokenAddress, token.decimals(), token.symbol());
    }


    /// @dev register the remote token with the provided attributes.
    /// this function may not be used for tokens when chainId == block.chainid.
    function registerRemoteToken(
        ChainId chainId,
        address token,
        uint8 decimals,
        string memory symbol
    )
        external
        restricted()
    {
        if (chainId == _chainId) {
            revert ErrorTokenRegistryNotRemoteToken(chainId, token);
        }

        _registerToken(chainId, token, decimals, symbol);
    }


    /// @dev set active flag on token itself.
    /// when setting a token to active=false isActive will return false
    /// regardless of release specific active value.
    function setActive(
        ChainId chainId, 
        address token, 
        bool active
    )
        external
        restricted()
        onlyRegisteredToken(chainId, token)
    {
        _tokenInfo[chainId][token].active = active;
        emit LogTokenRegistryTokenGlobalStateSet(chainId, token, active);
    }


    /// @dev sets active state for specified token and release (major version).
    /// internally calls setActiveWithVersionCheck() with enforcing version check.
    /// token state is informative, registry have no clue about used tokens
    /// component owner is responsible for token selection and operations
    /// service MUST deny registration of component with inactive token.
    function setActiveForVersion(
        ChainId chainId, 
        address token, 
        VersionPart release, 
        bool active
    )
        external
        restricted()
        onlyRegisteredToken(chainId, token)
    {
        _setActiveWithVersionCheck(chainId, token, release, active, true);
    }


    /// @dev as setActiveForVersion() with the option to skip the version check.
    /// enforcing the version check checks if the provided major version with the release manager. 
    /// the function reverts if the provided release is unknown to the release manager.
    function setActiveWithVersionCheck(
        ChainId chainId, 
        address token, 
        VersionPart release, 
        bool active,
        bool enforceVersionCheck
    )
        external
        restricted()
        onlyRegisteredToken(chainId, token)
    {
        _setActiveWithVersionCheck(chainId, token, release, active, enforceVersionCheck);
    }


    function _setActiveWithVersionCheck(
        ChainId chainId, 
        address token, 
        VersionPart release, 
        bool active,
        bool enforceVersionCheck
    )
        internal
    {
        // verify valid major version
        if(enforceVersionCheck) {
            uint256 version = release.toInt();
            if (!getRegistry().isActiveRelease(release)) {
                revert ErrorTokenRegistryMajorVersionInvalid(release);
            }
        }

        _active[chainId][token][release] = active;

        emit LogTokenRegistryTokenStateSet(chainId, token, release, active);
    }

    /// @dev returns the dip token for this chain
    function getDipToken() external view returns (IERC20Metadata dipToken) {
        return _dipToken;
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
    function getTokenInfo(ChainId chainId, address token) external view returns (TokenInfo memory tokenInfo) {
        return _tokenInfo[chainId][token];
    }

    /// @dev returns true iff the specified token has been registered for this TokenRegistry contract.
    function isRegistered(ChainId chainId, address token) public view returns (bool) {
        return _tokenInfo[chainId][token].chainId.gtz();
    }

    /// @dev returns true iff both the token is active for the specfied release and the global token state is active
    function isActive(ChainId chainId, address token, VersionPart release) external view returns (bool) {
        if(!_tokenInfo[chainId][token].active) {
            return false;
        }

        return _active[chainId][token][release];
    }

    function getDipTokenAddress() external view returns (address) {
        return address(_dipToken);
    }

    //--- IRegistryLinked --------------------------------------------------//

    /// @dev returns the dip token for this chain
    function getRegistry() public view returns (IRegistry) {
        return _registry;
    }

    //--- internal functions ------------------------------------------------//


    /// @dev checks if provided token address refers to a smart contract that implements 
    /// erc20 functionality (via its non-optional functions)
    function _verifyOnchainToken(address tokenAddress)
        internal
        virtual
        view
        returns (IERC20Metadata token)
    {
        token = IERC20Metadata(tokenAddress);

        // MUST be contract
        if(tokenAddress.code.length == 0) {
            revert ErrorTokenRegistryTokenNotContract(ChainIdLib.current(), tokenAddress);
        }

        // MUST implement required erc20 view functions
        if(!_implementsErc20Functions(token)) {
            revert ErrorTokenRegistryTokenNotErc20(ChainIdLib.current(), tokenAddress);
        }
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
    function _registerToken(ChainId chainId, address token, uint8 decimals, string memory symbol) internal {

        if (isRegistered(chainId, token)) {
            revert ErrorTokenRegistryTokenAlreadyRegistered(chainId, token);
        }

        if(chainId.eqz()) {
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
