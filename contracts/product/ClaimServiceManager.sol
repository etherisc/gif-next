// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {ClaimService} from "./ClaimService.sol";

contract ClaimServiceManager is ProxyManager {

    ClaimService private _claimService;

    /// @dev initializes proxy manager with service implementation 
    constructor(
        address authority,
        bytes32 salt
    ) 
    {
        ClaimService svc = new ClaimService{salt: salt}();
        bytes memory data = abi.encode(authority);
        IUpgradeable upgradeable = initialize(
            address(svc), 
            data,
            salt);

        _claimService = ClaimService(address(upgradeable));
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