// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev This is copy of OpenZeppelin's Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)
 * Changes:
 * 1. name is InitializableCustom
 * 2. no longer abstract
 * 3. have $._initializeOwner
 * 4. have constructor where sets _initializeOwner 
 * 5. initializer() in addition checks for _initializeOwner
 * 6. reinitializer() is deleted
 */
abstract contract InitializableCustom {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableCustomStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
        /**
         * @dev Indicates address that can call function with initializer() modifier.
         */
        address _initializeOwner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.InitializableCustom")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_CUSTOM_STORAGE = 0x46cd1d813423aaf613c34c7f348d15b2b5e71215e9145b09467e257ea2805a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract initialization function caller is not authorized.
     */
    error InvalidInitializationCaller();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableCustomStorage storage $ = _getInitializableCustomStorage();

        if($._initializeOwner != msg.sender) {
            revert InvalidInitializationCaller();
        }

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Constructor sets the caller of protected initializer function.
    */
    constructor(address initialOwner) {
        // solhint-disable-previous-line var-name-mixedcase
        InitializableCustomStorage storage $ = _getInitializableCustomStorage();
        $._initializeOwner = initialOwner;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableCustomStorage storage $ = _getInitializableCustomStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableCustomStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableCustomStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableCustomStorage() private pure returns (InitializableCustomStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_CUSTOM_STORAGE
        }
    }
}
