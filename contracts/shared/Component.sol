// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {IComponent} from "./IComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IComponentService} from "./IComponentService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT} from "../type/ObjectType.sol";
import {Registerable} from "../shared/Registerable.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {Version, VersionPart, VersionLib} from "../type/Version.sol";


abstract contract Component is
    Registerable,
    IComponent
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Component.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant COMPONENT_LOCATION_V1 = 0xffe8d4462baed26a47154f4b8f6db497d2f772496965791d25bd456e342b7f00;

    struct ComponentStorage {
        // slot 0
        IComponentService _componentService;
        // slot 1
        string _name; // unique (per instance) component name -> make pure to save gas?
        // slot 2
        bytes _data;
    }


    modifier onlyChainNft() {
        if(msg.sender != _getRegistry().getChainNftAddress()) {
            revert ErrorComponentNotChainNft(msg.sender);
        }
        _;
    }


    function _getComponentStorage() private pure returns (ComponentStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := COMPONENT_LOCATION_V1
        }
    }

    /// @dev requires component parent to be registered 
    function __Component_init(
        address authority,
        NftId parentNftId,
        string memory name,
        ObjectType componentType,
        bool isInterceptor,
        address initialOwner,
        bytes memory registryData // writeonly data that will saved in the object info record of the registry
    )
        internal
        virtual
        onlyInitializing()
    {
        if (bytes(name).length == 0) {
            revert ErrorComponentNameLengthZero();
        }

        __Registerable_init(
            authority,
            parentNftId, 
            componentType, 
            isInterceptor, 
            initialOwner, 
            registryData);

        // set component state
        ComponentStorage storage $ = _getComponentStorage();
        $._name = name;
        $._componentService = IComponentService(_getServiceAddress(COMPONENT()));

        _registerInterface(type(IAccessManaged).interfaceId);
        _registerInterface(type(IComponent).interfaceId);
    }


    /// @dev callback function for nft transfers
    /// may only be called by chain nft contract.
    /// override internal function _nftTransferFrom to implement custom behaviour
    function nftTransferFrom(address from, address to, uint256 tokenId, address operator)
        external
        onlyChainNft
    {
        _nftTransferFrom(from, to, tokenId, operator);
    }

    /// @inheritdoc IComponent
    function withdrawFees(Amount amount)
        external
        virtual
        restricted()
        onlyOwner()
        returns (Amount withdrawnAmount)
    {
        return _withdrawFees(amount);
    }


    function getWallet() public view virtual returns (address walletAddress) {
        return getTokenHandler().getWallet();
    }

    function getTokenHandler() public virtual view returns (TokenHandler tokenHandler) {
        return getComponentInfo().tokenHandler;
    }

    function getToken() public view virtual returns (IERC20Metadata token) {
        return getTokenHandler().TOKEN();
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



    function isRegistered() public virtual view returns (bool) {
        return _getRegistry().getNftIdForAddress(address(this)).gtz();
    }


    /// @dev Approves token hanlder to spend up to the specified amount of tokens.
    /// Reverts if component wallet is not token handler itself.
    /// Only component owner (nft holder) is authorizes to call this function.
    function _approveTokenHandler(IERC20Metadata token, Amount amount)
        internal
        virtual
        returns (Amount oldAllowanceAmount)
    {
        oldAllowanceAmount = AmountLib.toAmount(
            token.allowance(address(getTokenHandler()), address(this)));

        _getComponentStorage()._componentService.approveTokenHandler(
            token, 
            amount);
    }


    /// @dev internal function for nft transfers.
    /// handling logic that deals with nft transfers need to overwrite this function
    function _nftTransferFrom(address from, address to, uint256 tokenId, address operator)
        internal
        virtual
    // solhint-disable-next-line no-empty-blocks
    { 
        // empty default implementation
    }

    function _withdrawFees(Amount amount)
        internal
        returns (Amount withdrawnAmount)
    {
        return _getComponentStorage()._componentService.withdrawFees(amount);
    }

    /// @dev Sets the components wallet to the specified address.
    /// Depending on the source of the component information this function needs to be overwritten. 
    /// eg for instance linked components that externally store this information with the instance store contract
    function _setWallet(
        address newWallet
    )
        internal
        virtual
    {
        _getComponentStorage()._componentService.setWallet(newWallet);
    }

    function _setLocked(bool locked)
        internal
        virtual
    {
        _getComponentStorage()._componentService.setLocked(locked);
    }


    /// @dev depending on the source of the component information this function needs to be overwritten. 
    /// eg for instance linked components that externally store this information with the instance store contract
    function _getComponentInfo() internal virtual view returns (IComponents.ComponentInfo memory info) {
        ComponentStorage storage $ = _getComponentStorage();
        
        return IComponents.ComponentInfo({
            name: $._name,
            tokenHandler: TokenHandler(address(0))
        });
    }

    /// @dev returns the service address for the specified domain
    /// gets address via lookup from registry using the major version form the linked instance
    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return _getRegistry().getServiceAddress(domain, getRelease());
    }
}