// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {ClaimService} from "./ClaimService.sol";

contract ClaimServiceManager is ProxyManager {

    ClaimService private _claimService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        ClaimService svc = new ClaimService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IVersionable versionable = initialize(
            registry,
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