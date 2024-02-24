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
import {VersionLib} from "../types/Version.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId, RoleIdLib} from "../types/RoleId.sol";
import {IAccess} from "../instance/module/IAccess.sol";

// TODO also inherit oz accessmanaged
abstract contract Component is
    Registerable,
    IComponent
{
    using NftIdLib for NftId;

    IInstanceService internal _instanceService;
    IProductService internal _productService;

    address internal _deployer;
    address internal _wallet;
    IERC20Metadata internal _token;
    IInstance internal _instance;
    NftId internal _productNftId;

    modifier onlyProductService() {
        if(msg.sender != address(_productService)) {
            revert ErrorComponentNotProductService(msg.sender);
        }
        _;
    }

    modifier onlyInstanceRole(uint64 roleIdNum) {
        RoleId roleId = RoleIdLib.toRoleId(roleIdNum);
        InstanceAccessManager accessManager = InstanceAccessManager(_instance.authority());
        if( !accessManager.hasRole(roleId, msg.sender)) {
            revert ErrorComponentUnauthorized(msg.sender, roleIdNum);
        }
        _;
    }

    // TODO move to oz accessmanaged locked (which is included in restricted modifier)
    modifier isNotLocked() {
        InstanceAccessManager accessManager = InstanceAccessManager(_instance.authority());
        if (accessManager.isTargetLocked(address(this))) {
            revert IAccess.ErrorIAccessTargetLocked(address(this));
        }
        _;
    }

    constructor(
        address registry,
        NftId instanceNftId,
        address token,
        ObjectType componentType,
        bool isInterceptor,
        address initialOwner
    )
    {
        bytes memory data = "";
        _initializeRegisterable(registry, instanceNftId, componentType, isInterceptor, initialOwner, data);

        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        _instance = IInstance(instanceInfo.objectAddress);
        require(
            _instance.supportsInterface(type(IInstance).interfaceId),
            ""
        );

        _instanceService = IInstanceService(_registry.getServiceAddress(INSTANCE(), VersionLib.toVersion(3, 0, 0).toMajorPart()));
        _productService = IProductService(_registry.getServiceAddress(PRODUCT(), VersionLib.toVersion(3, 0, 0).toMajorPart()));
        _wallet = address(this);
        _token = IERC20Metadata(token);

        _registerInterface(type(IComponent).interfaceId);
    }

    // from component contract
    // TODO only owner and instance owner 
    function lock() external onlyOwner override {
        _instanceService.setTargetLocked(getName(), true);
    }
    
    // TODO only owner and instance owner 
    function unlock() external onlyOwner override {
        _instanceService.setTargetLocked(getName(), false);
    }

    function setProductNftId(NftId productNftId)
        public
        override
        onlyProductService() 
    {
        if(_productNftId.gtz()) {
            revert ErrorComponentProductNftAlreadySet();
        }

        _productNftId = productNftId;
    }

    /// @dev Sets the wallet address for the component. 
    /// if the current wallet has tokens, these will be transferred. 
    /// if the new wallet address is externally owned, an approval from the 
    /// owner of the external wallet for the component to move all tokens must exist. 
    function setWallet(address newWallet) external override onlyOwner {
        address currentWallet = _wallet;
        uint256 currentBalance = _token.balanceOf(currentWallet);

        // checks
        if (newWallet == currentWallet) {
            revert ErrorComponentWalletAddressIsSameAsCurrent(newWallet);
        }

        if (currentBalance > 0) {
            if (currentWallet == address(this)) {
                // move tokens from component smart contract to external wallet
            } else {
                // move tokens from external wallet to component smart contract or another external wallet
                uint256 allowance = _token.allowance(currentWallet, address(this));
                if (allowance < currentBalance) {
                    revert ErrorComponentWalletAllowanceTooSmall(currentWallet, newWallet, allowance, currentBalance);
                }
            }
        }

        // effects
        _wallet = newWallet;
        emit LogComponentWalletAddressChanged(newWallet);

        // interactions
        if (currentBalance > 0) {
            // transfer tokens from current wallet to new wallet
            if (currentWallet == address(this)) {
                // transferFrom requires self allowance too
                _token.approve(address(this), currentBalance);
            }
            
            SafeERC20.safeTransferFrom(_token, currentWallet, newWallet, currentBalance);
            emit LogComponentWalletTokensTransferred(currentWallet, newWallet, currentBalance);
        }
    }

    function getName() public pure virtual returns (string memory name);

    function getWallet()
        external
        view
        override
        returns (address walletAddress)
    {
        return _wallet;
    }

    function getToken() public view override returns (IERC20Metadata token) {
        return _token;
    }

    function getInstance() public view override returns (IInstance instance) {
        return _instance;
    }

    function getProductNftId() public view override returns (NftId productNftId) {
        return _productNftId;
    }
}
