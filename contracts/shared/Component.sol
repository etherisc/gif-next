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
import {InstanceAdmin} from "../instance/InstanceAdmin.sol";
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

// TODO discuss to inherit from oz accessmanaged
// then add (Distribution|Pool|Product)Upradeable that also intherit from Versionable
// same pattern as for Service which is also upgradeable
abstract contract Component is
    Registerable,
    IComponent,
    AccessManagedUpgradeable
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Component.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant COMPONENT_LOCATION_V1 = 0xffe8d4462baed26a47154f4b8f6db497d2f772496965791d25bd456e342b7f00;

    struct ComponentStorage {
        string _name; // unique (per instance) component name
        IERC20Metadata _token; // token for this component
        IInstance _instance; // instance for this component
        address _wallet; // wallet for this component (default = component contract itself)
        InstanceReader _instanceReader; // instance reader for this component
        bool _isNftInterceptor; // declares if component is involved in nft transfers
        NftId _productNftId; // only relevant for components that are linked to a aproduct
    }

    function _getComponentStorage() private pure returns (ComponentStorage storage $) {
        assembly {
            $.slot := COMPONENT_LOCATION_V1
        }
    }

    modifier onlyChainNft() {
        if(msg.sender != getRegistry().getChainNftAddress()) {
            revert ErrorComponentNotChainNft(msg.sender);
        }
        _;
    }

    function initializeComponent(
        address registry,
        NftId instanceNftId,
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
        initializeRegisterable(registry, instanceNftId, componentType, isInterceptor, initialOwner, registryData);

        // set and check linked instance
        ComponentStorage storage $ = _getComponentStorage();
        $._instance = IInstance(
            getRegistry().getObjectInfo(instanceNftId).objectAddress);

        if(!$._instance.supportsInterface(type(IInstance).interfaceId)) {
            revert ErrorComponentNotInstance(instanceNftId);
        }

        // initialize AccessManagedUpgradeable
        __AccessManaged_init($._instance.authority());

        // set component state
        $._name = name;
        $._isNftInterceptor = isInterceptor;
        $._instanceReader = $._instance.getInstanceReader();
        $._wallet = address(this);
        $._token = IERC20Metadata(token);

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IComponent).interfaceId);
    }

    function lock() external onlyOwner {
        IInstanceService(_getServiceAddress(INSTANCE())).setComponentLocked(true);
    }
    
    function unlock() external onlyOwner {
        IInstanceService(_getServiceAddress(INSTANCE())).setComponentLocked(false);
    }

    function approveTokenHandler(uint256 spendingLimitAmount) external onlyOwner {
        IComponents.ComponentInfo memory info = getComponentInfo();

        if(info.wallet != address(this)) {
            revert ErrorComponentWalletNotComponent();
        }

        info.token.approve(
            address(info.tokenHandler),
            spendingLimitAmount);

        emit LogComponentTokenHandlerApproved(spendingLimitAmount);
    }

    function setWallet(address newWallet)
        external
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

    function setProductNftId(NftId productNftId)
        external
        override
    {
        ComponentStorage storage $ = _getComponentStorage();

        // verify caller is product service
        if(msg.sender != _getServiceAddress(PRODUCT())) {
            revert ErrorComponentNotProductService(msg.sender);
        }

        // verify component is not yet linked to a product
        if($._productNftId.gtz()) {
            revert ErrorComponentProductNftAlreadySet();
        }

        $._productNftId = productNftId;
    }

    function nftMint(address to, uint256 tokenId) 
        external 
        virtual
        onlyChainNft
    {}

    /// @dev callback function for nft transfers
    /// may only be called by chain nft contract.
    /// do not override this function to implement business logic for handling transfers
    /// override internal function _nftTransferFrom instead
    function nftTransferFrom(address from, address to, uint256 tokenId)
        external
        virtual
        onlyChainNft
    {
        _nftTransferFrom(from, to, tokenId);
    }

    function getWallet() public view override returns (address walletAddress)
    {
        return _getComponentStorage()._wallet;
    }

    function getToken() public view override returns (IERC20Metadata token) {
        return _getComponentStorage()._token;
    }

    function getTokenHandler() public view returns (TokenHandler tokenHandler) {
        return getComponentInfo().tokenHandler;
    }

    function isNftInterceptor() public view override returns(bool isInterceptor) {
        return _getComponentStorage()._isNftInterceptor;
    }

    function getInstance() public view override returns (IInstance instance) {
        return _getComponentStorage()._instance;
    }

    function getName() public view override returns(string memory name) {
        return _getComponentStorage()._name;
    }

    function getProductNftId() public view override returns (NftId productNftId) {
        return _getComponentStorage()._productNftId;
    }

    function getComponentInfo() public view returns (IComponents.ComponentInfo memory info) {
        info = _getInstanceReader().getComponentInfo(getNftId());

        // fallback to initial info (wallet is always != address(0))
        if(info.wallet == address(0)) {
            info = _getInitialInfo();
        }
    }

    /// @dev defines initial component specification
    /// overwrite this function according to your use case
    function _getInitialInfo()
        internal
        view 
        virtual
        returns (IComponents.ComponentInfo memory info)
    { }


    /// @dev internal function for nft transfers.
    /// handling logic that deals with nft transfers need to overwrite this function
    function _nftTransferFrom(address from, address to, uint256 tokenId)
        internal
        virtual
    { }

    /// @dev returns reader for linked instance
    function _getInstanceReader() internal view returns (InstanceReader reader) {
        return _getComponentStorage()._instanceReader;
    }

    /// @dev returns the service address for the specified domain
    /// gets address via lookup from registry using the major version form the linked instance
    function _getServiceAddress(ObjectType domain) internal view returns (address service) {
        VersionPart majorVersion = _getComponentStorage()._instance.getMajorVersion();
        return getRegistry().getServiceAddress(domain, majorVersion);
    }
}