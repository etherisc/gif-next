// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../shared/IVersionable.sol";
import {ProxyManager} from "../shared/ProxyManager.sol";
import {ClaimService} from "./ClaimService.sol";

contract ClaimServiceManager is ProxyManager {

    ClaimService private _claimService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        ClaimService svc = new ClaimService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(svc), 
            data,
            salt);

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