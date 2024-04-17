// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IComponent} from "./IComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceAccessManager} from "../instance/InstanceAccessManager.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE, PRODUCT} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {IAccess} from "../instance/module/IAccess.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";

abstract contract Component is
    AccessManagedUpgradeable,
    Registerable,
    IComponent
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Component.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant COMPONENT_LOCATION_V1 = 0xffe8d4462baed26a47154f4b8f6db497d2f772496965791d25bd456e342b7f00;

    struct ComponentStorage {
        string _name; // unique (per instance) component name
        IERC20Metadata _token; // token for this component
        TokenHandler _tokenHandler; // token handler for this component
        address _wallet; // wallet for this component (default = component contract itself)
    }

    function _getComponentStorage() private pure returns (ComponentStorage storage $) {
        assembly {
            $.slot := COMPONENT_LOCATION_V1
        }
    }

    function initializeComponent(
        address authority,
        address registry,
        NftId parentNftId,
        string memory name,
        address token,
        ObjectType componentType,
        bool isInterceptor,
        address initialOwner,
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        public
        virtual
        onlyInitializing()
    {
        initializeRegisterable(registry, parentNftId, componentType, isInterceptor, initialOwner, registryData);
        __AccessManaged_init(authority);

        if (token == address(0)) {
            revert ErrorComponentTokenAddressZero();
        }

        // set component state
        ComponentStorage storage $ = _getComponentStorage();
        $._name = name;
        $._wallet = address(this);
        $._token = IERC20Metadata(token);
        $._tokenHandler = new TokenHandler(token);

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IComponent).interfaceId);
    }

    function approveTokenHandler(uint256 spendingLimitAmount)
        external
        virtual
        onlyOwner
    {
        ComponentStorage storage $ = _getComponentStorage();
        approveTokenHandler(address($._token), spendingLimitAmount);
    }

    function approveTokenHandler(address token, uint256 spendingLimitAmount)
        public
        virtual
        onlyOwner
    {
        ComponentStorage storage $ = _getComponentStorage();

        if($._wallet != address(this)) {
            revert ErrorComponentWalletNotComponent();
        }

        IERC20Metadata(token).approve(
            address($._tokenHandler),
            spendingLimitAmount);

        emit LogComponentTokenHandlerApproved(token, spendingLimitAmount);
    }

    function setWallet(address newWallet)
        external
        virtual
        override
        onlyOwner
    {
        ComponentStorage storage $ = _getComponentStorage();
        address currentWallet = $._wallet;
        uint256 currentBalance = $._token.balanceOf(currentWallet);

        // checks
        if (newWallet == address(0)) {
            revert ErrorComponentWalletAddressZero();
        }

        if (newWallet == currentWallet) {
            revert ErrorComponentWalletAddressIsSameAsCurrent();
        }

        if (currentBalance > 0) {
            if (currentWallet == address(this)) {
                // move tokens from component smart contract to external wallet
            } else {
                // move tokens from external wallet to component smart contract or another external wallet
                uint256 allowance = $._token.allowance(currentWallet, address(this));
                if (allowance < currentBalance) {
                    revert ErrorComponentWalletAllowanceTooSmall(currentWallet, newWallet, allowance, currentBalance);
                }
            }
        }

        // effects
        $._wallet = newWallet;
        emit LogComponentWalletAddressChanged(currentWallet, newWallet);

        // interactions
        if (currentBalance > 0) {
            // transfer tokens from current wallet to new wallet
            if (currentWallet == address(this)) {
                // transferFrom requires self allowance too
                $._token.approve(address(this), currentBalance);
            }
            
            SafeERC20.safeTransferFrom($._token, currentWallet, newWallet, currentBalance);
            emit LogComponentWalletTokensTransferred(currentWallet, newWallet, currentBalance);
        }
    }

    function getWallet() public view virtual returns (address walletAddress)
    {
        return _getComponentStorage()._wallet;
    }

    function getToken() public view virtual returns (IERC20Metadata token) {
        return _getComponentStorage()._token;
    }

    function getTokenHandler() public view virtual returns (TokenHandler tokenHandler) {
        return _getComponentStorage()._tokenHandler;
    }

    function getName() public view override returns(string memory name) {
        return _getComponentStorage()._name;
    }

    /// @dev internal function for nft transfers.
    /// handling logic that deals with nft transfers need to overwrite this function
    function _nftTransferFrom(address from, address to, uint256 tokenId)
        internal
        virtual
    { }
}