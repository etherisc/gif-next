// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../../shared/IVersionable.sol";
import {ProxyManager} from "../../shared/ProxyManager.sol";
import {ClaimService} from "./ClaimService.sol";

contract ClaimServiceManager is ProxyManager {

    ClaimService private _claimService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address registryAddress
    )
        ProxyManager(registryAddress)
    {
        ClaimService svc = new ClaimService();
        bytes memory data = abi.encode(registryAddress, address(this));
        IVersionable versionable = deploy(
            address(svc), 
            data);

        _claimService = ClaimService(address(versionable));
    }

    //--- view functions ----------------------------------------------------//
    function getClaimService()
        external
        view
        returns (ClaimService)
    {
        return _claimService;
    }
}