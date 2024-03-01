// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IComponent} from "./IComponent.sol";
import {IProductService} from "../instance/service/IProductService.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceAccessManager} from "../instance/InstanceAccessManager.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId, zeroNftId, NftIdLib} from "../types/NftId.sol";
import {ObjectType, INSTANCE, PRODUCT} from "../types/ObjectType.sol";
import {VersionPart} from "../types/Version.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId, RoleIdLib} from "../types/RoleId.sol";
import {IAccess} from "../instance/module/IAccess.sol";

// TODO discuss to inherit from oz accessmanaged
// TODO make contract upgradeable
// then add (Distribution|Pool|Product)Upradeable that also intherit from Versionable
// same pattern as for Service which is also upgradeable
abstract contract Component is
    Registerable,
    IComponent
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Component.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant CONTRACT_LOCATION_V1 = 0xffe8d4462baed26a47154f4b8f6db497d2f772496965791d25bd456e342b7f00;

    struct ComponentStorage {
        IInstance _instance; // instance for this component

        string _name; // unique (per instance) component name
        IERC20Metadata _token; // token for this component
        address _wallet; // wallet for this component (default = component contract itself)
        bool _isNftInterceptor; // declares if component is involved in nft transfers
        IInstanceService _instanceService; // instance service for this component

        NftId _productNftId; // only relevant for components that are linked to a aproduct
        IProductService _productService; // product service for component, might not be relevant for some component types (eg oracles)
    }


    modifier onlyChainNft() {
        if(msg.sender != address(getRegistry().getChainNft())) {
            revert ErrorComponentNotChainNft(msg.sender);
        }
        _;
    }


    modifier onlyProductService() {
        if(msg.sender != address(_getComponentStorage()._productService)) {
            revert ErrorComponentNotProductService(msg.sender);
        }
        _;
    }

    // TODO discuss replacement with modifier restricted from accessmanaged
    modifier onlyInstanceRole(uint64 roleIdNum) {
        RoleId roleId = RoleIdLib.toRoleId(roleIdNum);
        InstanceAccessManager accessManager = InstanceAccessManager(_getComponentStorage()._instance.authority());
        if( !accessManager.hasRole(roleId, msg.sender)) {
            revert ErrorComponentUnauthorized(msg.sender, roleIdNum);
        }
        _;
    }

    // TODO discuss replacement with modifier restricted from accessmanaged
    modifier isNotLocked() {
        InstanceAccessManager accessManager = InstanceAccessManager(_getComponentStorage()._instance.authority());
        if (accessManager.isTargetLocked(address(this))) {
            revert IAccess.ErrorIAccessTargetLocked(address(this));
        }
        _;
    }

    function _getComponentStorage() private pure returns (ComponentStorage storage $) {
        assembly {
            $.slot := CONTRACT_LOCATION_V1
        }
    }


    function _initializeComponent(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        ObjectType componentType,
        bool isInterceptor,
        address initialOwner,
        bytes memory data
    )
        internal
        //onlyInitializing//TODO uncomment when "fully" upgradeable
        virtual
    {
        ComponentStorage storage $ = _getComponentStorage();
        _initializeRegisterable(registry, instanceNftId, componentType, isInterceptor, initialOwner, data);

        // set unique name of component
        $._name = name;
        $._isNftInterceptor = isInterceptor;

        // set and check linked instance
        IRegistry.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);
        $._instance = IInstance(instanceInfo.objectAddress);
        if(!$._instance.supportsInterface(type(IInstance).interfaceId)) {
            revert ErrorComponentNotInstance(instanceNftId, instanceInfo.objectAddress);
        }

        // set linked services
        VersionPart gifVersion = $._instance.getMajorVersion();
        $._instanceService = IInstanceService(getRegistry().getServiceAddress(INSTANCE(), gifVersion));
        $._productService = IProductService(getRegistry().getServiceAddress(PRODUCT(), gifVersion));

        // set wallet and token
        $._wallet = address(this);
        $._token = IERC20Metadata(token);

        _registerInterface(type(IComponent).interfaceId);
    }

    /// @dev callback function for nft transfers. may only be called by chain nft contract.
    /// default implementation is empty. overriding functions MUST add onlyChainNft modifier
    function nftTransferFrom(address from, address to, uint256 tokenId)
        external
        virtual override
        onlyChainNft()
    { }

    // TODO discuss replacement with modifier restricted from accessmanaged
    function lock() external onlyOwner override {
        _getComponentStorage()._instanceService.setTargetLocked(getName(), true);
    }
    
    // TODO discuss replacement with modifier restricted from accessmanaged
    function unlock() external onlyOwner override {
        _getComponentStorage()._instanceService.setTargetLocked(getName(), false);
    }

    // only product service may set product nft id during registration of product setup
    function setProductNftId(NftId productNftId)
        external
        override
        onlyProductService() 
    {
        ComponentStorage storage $ = _getComponentStorage();

        if($._productNftId.gtz()) {
            revert ErrorComponentProductNftAlreadySet();
        }

        $._productNftId = productNftId;
    }

    /// @dev Sets the wallet address for the component. 
    /// if the current wallet has tokens, these will be transferred. 
    /// if the new wallet address is externally owned, an approval from the 
    /// owner of the external wallet for the component to move all tokens must exist. 
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
            revert ErrorComponentWalletAddressIsSameAsCurrent(newWallet);
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
        emit LogComponentWalletAddressChanged(newWallet);

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

    function getWallet()
        public
        view
        override
        returns (address walletAddress)
    {
        return _getComponentStorage()._wallet;
    }

    function getToken() public view override returns (IERC20Metadata token) {
        return _getComponentStorage()._token;
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

    function getInstanceService() public view returns (IInstanceService) {
        return _getComponentStorage()._instanceService;
    }

    function getProductService() public view returns (IProductService) {
        return _getComponentStorage()._productService;
    }

}
