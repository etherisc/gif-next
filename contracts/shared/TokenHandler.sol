// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {ContractLib} from "../shared/ContractLib.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {SERVICE} from "../type/ObjectType.sol";


contract TokenHandlerBase {

    // _setWallet
    event LogTokenHandlerWalletAddressChanged(NftId componentNftId, address oldWallet, address newWallet);
    event LogTokenHandlerWalletTokensTransferred(NftId componentNftId, address oldWallet, address newWallet, Amount amount);

    // _approveTokenHandler
    event LogTokenHandlerTokenApproved(NftId nftId, address tokenHandler, address token, Amount amount, bool isMaxAmount);

    // _transfer
    event LogTokenHandlerTokenTransfer(address token, address from, address to, Amount amount);

    // constructor
    error ErrorTokenHandlerNotRegistry(address registry);
    error ErrorTokenHandlerComponentNotRegistered(address component);
    error ErrorTokenHandlerTokenAddressZero();

    // _setWallet
    error ErrorTokenHandlerNewWalletAddressZero();
    error ErrorTokenHandlerAddressIsSameAsCurrent();

    // _approveTokenHandler
    error ErrorTokenHandlerNotWallet(NftId nftId, address tokenHandler, address wallet);

    // _pullAndPullToken
    error ErrorTokenHandlerWalletsNotDistinct(address from, address to1, address to2);
    error ErrorTokenHandlerPushAmountsTooLarge(Amount pushAmount, Amount pullAmount);

    // _checkPreconditions
    error ErrorTokenHandlerBalanceTooLow(address token, address from, uint256 balance, uint256 expectedBalance);
    error ErrorTokenHandlerAllowanceTooSmall(address token, address from, address spender, uint256 allowance, uint256 expectedAllowance);
    error ErrorTokenHandlerAmountIsZero();

    IRegistry public immutable REGISTRY;
    IERC20Metadata public immutable TOKEN;
    address public immutable COMPONENT;
    NftId public immutable NFT_ID;

    address internal _wallet;

    constructor(
        address registry,
        address component,
        address token
    )
    {
        if (!ContractLib.isRegistry(registry)) {
            revert ErrorTokenHandlerNotRegistry(registry);
        }

        if (token == address(0)) {
            revert ErrorTokenHandlerTokenAddressZero();
        }

        REGISTRY = IRegistry(registry);
        COMPONENT = component;
        NFT_ID = REGISTRY.getNftIdForAddress(component);

        if (NFT_ID.eqz()) {
            revert ErrorTokenHandlerComponentNotRegistered(component);
        }

        TOKEN = IERC20Metadata(token);
    }


    /// @dev Returns the wallet linked to this TokenHandler.
    function getWallet()
        public
        view 
        returns (address wallet)
    {
        if (_wallet == address(0)) {
            return address(this);
        }

        return _wallet;
    }


    /// @dev Approves token handler to spend up to the specified amount of tokens.
    /// Sets spending limit to type(uint256).max for AmountLib.max().
    /// Reverts if wallet is not token handler itself.
    /// Sets approvel using SareERC20.forceApprove internally.
    function _approve(
        IERC20Metadata token, 
        Amount amount
    )
        internal
    {
        // check that wallet is token handler contract itself
        if(_wallet != address(0)) {
            revert ErrorTokenHandlerNotWallet(NFT_ID, address(this), _wallet);
        }

        // update spending limit for AmountLib.max() to type(uint256).max
        uint256 amountInt = amount.toInt();
        bool isMaxAmount = false;
        if (amount == AmountLib.max()) {
            amountInt = type(uint256).max;
            isMaxAmount = true;
        }

        emit LogTokenHandlerTokenApproved(NFT_ID, address(this), address(token), amount, isMaxAmount);

        // execute approval
        SafeERC20.forceApprove(
            token, 
            address(this), 
            amountInt);
    }


    function _setWallet(address newWallet)
        internal
    {
        address oldWallet = _wallet;
        if (newWallet == oldWallet) {
            revert ErrorTokenHandlerAddressIsSameAsCurrent();
        }

        // effects
        address oldWalletForBalance = getWallet();
        _wallet = newWallet;

        emit LogTokenHandlerWalletAddressChanged(NFT_ID, oldWallet, newWallet);

        // interactions
        Amount balanceAmount = AmountLib.toAmount(
            TOKEN.balanceOf(oldWalletForBalance));

        if (balanceAmount.gtz()) {
            // move tokens from old to new wallet 
            emit LogTokenHandlerWalletTokensTransferred(NFT_ID, oldWallet, newWallet, balanceAmount);

            if (oldWallet == address(0)) {
                // transfer from the component requires an allowance
                _transfer(address(this), newWallet, balanceAmount, true);
            } else if (newWallet == address(0)) {
                _transfer(oldWallet, address(this), balanceAmount, true);
            } else {
                _transfer(oldWallet, newWallet, balanceAmount, true);
            }
        }
    }


    function _pullAndPushToken(
        address from, 
        Amount pullAmount,
        address to1,
        Amount amount1,
        address to2,
        Amount amount2
    )
        internal
    {
        address wallet = getWallet();

        if (wallet == to1 || wallet == to2 || to1 == to2) {
            revert ErrorTokenHandlerWalletsNotDistinct(wallet, to1, to2);
        }

        if (amount1 + amount2 > pullAmount) {
            revert ErrorTokenHandlerPushAmountsTooLarge(amount1 + amount2, pullAmount);
        }

        _pullToken(from, pullAmount);

        if (amount1.gtz()) { _pushToken(to1, amount1); }
        if (amount2.gtz()) { _pushToken(to2, amount2); }
    }


    function _pullToken(address from, Amount amount)
        internal
    {
        _transfer(from, getWallet(), amount, true);
    }


    function _pushToken(address to, Amount amount)
        internal
    {
        _transfer(getWallet(), to, amount, true);
    }


    function _transfer(
        address from,
        address to,
        Amount amount,
        bool checkPreconditions
    )
        internal
    {
        if (checkPreconditions) {
            // check amount > 0, balance >= amount and allowance >= amount
            _checkPreconditions(from, amount);
        }

        // transfer the tokens
        emit LogTokenHandlerTokenTransfer(address(TOKEN), from, to, amount);

        SafeERC20.safeTransferFrom(
            TOKEN, 
            from, 
            to, 
            amount.toInt());
    }


    function _checkPreconditions(
        address from,
        Amount amount
    ) 
        internal
        view
    {
        // amount must be greater than zero
        if (amount.eqz()) {
            revert ErrorTokenHandlerAmountIsZero();
        }

        // allowance must be >= amount
        uint256 allowance = TOKEN.allowance(from, address(this));
        if (allowance < amount.toInt()) {
            revert ErrorTokenHandlerAllowanceTooSmall(address(TOKEN), from, address(this), allowance, amount.toInt());
        }

        // balance must be >= amount
        uint256 balance = TOKEN.balanceOf(from);
        if (balance < amount.toInt()) {
            revert ErrorTokenHandlerBalanceTooLow(address(TOKEN), from, balance, amount.toInt());
        }
    }
}


/// @dev Token specific transfer helper
/// a default token contract is provided via contract constructor
/// relies internally on oz SafeERC20.safeTransferFrom
contract TokenHandler is
    AccessManaged,
    TokenHandlerBase
{

    // onlyService
    error ErrorTokenHandlerNotService(address service);

    // TODO delete
    error ErrorTokenHandlerRecipientWalletsMustBeDistinct(address to, address to2, address to3);

    modifier onlyService() {
        if (!REGISTRY.isObjectType(msg.sender, SERVICE())) {
            revert ErrorTokenHandlerNotService(msg.sender);
        }
        _;
    }

    constructor(
        address registry,
        address component,
        address token, 
        address authority
    )
        TokenHandlerBase(registry, component, token)
        AccessManaged(authority)
    { }

    /// @dev sets the wallet address for the component.
    /// if the current wallet has tokens, these will be transferred.
    /// if the new wallet address is externally owned, an approval from the 
    /// owner of the external wallet to the tokenhandler of the component that 
    /// covers the current component balance must exist
    function setWallet(address newWallet)
        external
        // restricted() // TODO re-activate
        onlyService()
    {
        _setWallet(newWallet);
    }


    /// @dev Approves token handler to spend up to the specified amount of tokens.
    /// Sets spending limit to type(uint256).max for AmountLib.max().
    /// Reverts if component wallet is not component itself.
    /// Sets approvel using SareERC20.forceApprove internally.
    function approve(
        IERC20Metadata token, 
        Amount amount
    )
        external
        // restricted() // TODO re-activate
        onlyService()
    {
        _approve(token, amount);
    }

    /// @dev Collect tokens from outside of GIF and transfer them to the wallet.
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function collectTokens(
        address from,
        Amount amount
    )
        external
        // restricted() // TODO re-activate
        onlyService()
    {
        _pullToken(from, amount);
    }


    /// @dev Collect tokens from outside of GIF and transfer them to the wallet.
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function pushToken(
        address from,
        Amount amount
    )
        external
        // restricted() // TODO re-activate
        onlyService()
    {
        _pushToken(from, amount);
    }


    /// @dev collect tokens from outside of the gif and transfer them to three distinct wallets within the scope of gif
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function collectTokensToThreeRecipients( 
        address from,
        address to,
        Amount amount,
        address to2,
        Amount amount2,
        address to3,
        Amount amount3
    )
        external
        restricted()
        onlyService()
    {
        if (to == to2 || to == to3 || to2 == to3) {
            revert ErrorTokenHandlerRecipientWalletsMustBeDistinct(to, to2, to3);
        }

        _checkPreconditions(from, amount + amount2 + amount3);

        if (amount.gtz()) {
            _transfer(from, to, amount, false);
        }
        if (amount2.gtz()) {
            _transfer(from, to2, amount2, false);
        }
        if (amount3.gtz()) {
            _transfer(from, to3, amount3, false);
        }
    }


    /// @dev distribute tokens from a wallet within the scope of gif to an external address.
    /// This method also checks balance and allowance and makes sure the amount is greater than zero.
    function distributeTokens(
        address from,
        address to,
        Amount amount
    )
        external
        restricted()
        onlyService()
    {
        // _transfer(from, to, amount, true);
        _pushToken(to, amount);
    }
}
