// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {IComponent} from "./IComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPartLib} from "../type/Version.sol";

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
        address _wallet;
        bool _isInterceptor;
        bytes _data;
    }


    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert ErrorComponentNotChainNft(msg.sender);
        }
        _;
    }

    modifier onlyNftOwner(NftId nftId) {
        if(msg.sender != getRegistry().ownerOf(nftId)) {
            revert ErrorNftOwnableNotOwner(msg.sender);
        }
        _;
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
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // other component specific data
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

        if (bytes(name).length == 0) {
            revert ErrorComponentNameLengthZero();
        }

        // set component state
        ComponentStorage storage $ = _getComponentStorage();
        $._name = name;
        $._token = IERC20Metadata(token);
        $._wallet = address(this);
        $._isInterceptor = isInterceptor;
        $._data = componentData;

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IComponent).interfaceId);
    }


    function approveTokenHandler(Amount spendingLimitAmount)
        external
        virtual
        onlyOwner
    {
        approveTokenHandler(address(getToken()), spendingLimitAmount);
    }

    function approveTokenHandler(address token, Amount spendingLimitAmount)
        public
        virtual
        onlyOwner
    {
        if(getWallet() != address(this)) {
            revert ErrorComponentWalletNotComponent();
        }

        emit LogComponentTokenHandlerApproved(address(getTokenHandler()), spendingLimitAmount);

        IERC20Metadata(token).approve(
            address(getTokenHandler()),
            spendingLimitAmount.toInt());
    }

    function setWallet(address newWallet)
        external
        virtual
        override
        onlyOwner
    {
        // checks
        address currentWallet = getWallet();
        IERC20Metadata token = getToken();
        uint256 currentBalance = token.balanceOf(currentWallet);

        if (currentBalance > 0) {
            if (currentWallet == address(this)) {
                // move tokens from component smart contract to external wallet
            } else {
                // move tokens from external wallet to component smart contract or another external wallet
                uint256 allowance = token.allowance(currentWallet, address(getTokenHandler()));
                if (allowance < currentBalance) {
                    revert ErrorComponentWalletAllowanceTooSmall(currentWallet, newWallet, allowance, currentBalance);
                }
            }
        }

        // effects
        _setWallet(newWallet);

        // interactions
        if (currentBalance > 0) {
            emit LogComponentWalletTokensTransferred(currentWallet, newWallet, currentBalance);

            // transfer tokens from current wallet to new wallet
            if (currentWallet == address(this)) {
                // transferFrom requires self allowance too
                token.approve(address(getTokenHandler()), currentBalance);
            }
            
            getTokenHandler().transfer(currentWallet, newWallet, AmountLib.toAmount(currentBalance));
        }
    }


    /// @dev callback function for nft mints
    /// may only be called by chain nft contract.
    /// override internal function _nftMint to implement custom behaviour
    function nftMint(address to, uint256 tokenId) 
        external 
        onlyChainNft
    {
        _nftMint(to, tokenId);
    }

    /// @dev callback function for nft transfers
    /// may only be called by chain nft contract.
    /// override internal function _nftTransferFrom to implement custom behaviour
    function nftTransferFrom(address from, address to, uint256 tokenId)
        external
        onlyChainNft
    {
        _nftTransferFrom(from, to, tokenId);
    }


    function getWallet() public view virtual returns (address walletAddress) {
        return getComponentInfo().wallet;
    }

    function getTokenHandler() public virtual view returns (TokenHandler tokenHandler) {
        return getComponentInfo().tokenHandler;
    }

    function getToken() public view virtual returns (IERC20Metadata token) {
        return getComponentInfo().token;
    }

    function getName() public view override returns(string memory name) {
        return getComponentInfo().name;
    }

    function getComponentInfo() public virtual view returns (IComponents.ComponentInfo memory info) {
        if (isRegistered()) {
            return _getComponentInfo();
        } else {
            return getInitialComponentInfo();
        }
    }

    /// @dev defines initial component specification
    /// overwrite this function according to your use case
    function getInitialComponentInfo() public virtual view returns (IComponents.ComponentInfo memory info) {
        return _getComponentInfo();
    }


    function isNftInterceptor() public virtual view returns(bool isInterceptor) {
        if (isRegistered()) {
            return getRegistry().getObjectInfo(address(this)).isInterceptor;
        } else {
            return _getComponentStorage()._isInterceptor;
        }
    }


    function isRegistered() public virtual view returns (bool) {
        return getRegistry().getNftId(address(this)).gtz();
    }


    /// @dev internal function for nft transfers.
    /// handling logic that deals with nft transfers need to overwrite this function
    function _nftMint(address to, uint256 tokenId)
        internal
        virtual
    { }

    /// @dev internal function for nft transfers.
    /// handling logic that deals with nft transfers need to overwrite this function
    function _nftTransferFrom(address from, address to, uint256 tokenId)
        internal
        virtual
    { }


    /// @dev depending on the source of the component information this function needs to be overwritten. 
    /// eg for instance linked components that externally store this information with the instance store contract
    function _setWallet(address newWallet) internal virtual {
        ComponentStorage storage $ = _getComponentStorage();
        address currentWallet = $._wallet;

        if (newWallet == address(0)) {
            revert ErrorComponentWalletAddressZero();
        }

        if (newWallet == currentWallet) {
            revert ErrorComponentWalletAddressIsSameAsCurrent();
        }

        $._wallet = newWallet;
        emit LogComponentWalletAddressChanged(currentWallet, newWallet);

    }


    /// @dev depending on the source of the component information this function needs to be overwritten. 
    /// eg for instance linked components that externally store this information with the instance store contract
    function _getComponentInfo() internal virtual view returns (IComponents.ComponentInfo memory info) {
        ComponentStorage storage $ = _getComponentStorage();
        
        return IComponents.ComponentInfo({
            name: $._name,
            productNftId: NftIdLib.zero(),
            token: $._token,
            tokenHandler: TokenHandler(address(0)),
            wallet: $._wallet, // initial wallet address
            data: $._data // user specific component data
        });
    }

    function _approveTokenHandler(uint256 amount) internal {
        ComponentStorage storage $ = _getComponentStorage();
        $._token.approve(address(getComponentInfo().tokenHandler), amount);
    }

}