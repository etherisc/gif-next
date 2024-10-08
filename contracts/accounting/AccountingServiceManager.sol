// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccountingService} from "./AccountingService.sol";
import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";

contract AccountingServiceManager is ProxyManager {

    AccountingService private _accountingService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    )
    {
        AccountingService svc = new AccountingService();
        bytes memory data = abi.encode(authority, registry);
        IVersionable versionable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _accountingService = AccountingService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getAccountingService()
        external
        view
        returns (AccountingService)
    {
        return _accountingService;
    }
}