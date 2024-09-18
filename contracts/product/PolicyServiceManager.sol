// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IUpgradeable} from "../upgradeability/IUpgradeable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {PolicyService} from "./PolicyService.sol";

contract PolicyServiceManager is ProxyManager {

    PolicyService private _policyService;

    /// @dev initializes proxy manager with product service implementation 
    constructor(
        address authority, 
        address registry,
        bytes32 salt
    ) 
    {
        PolicyService svc = new PolicyService{salt: salt}();
        bytes memory data = abi.encode(authority, registry);
        IUpgradeable upgradeable = initialize(
            registry,
            address(svc), 
            data,
            salt);

        _policyService = PolicyService(address(upgradeable));
    }

    //--- view functions ----------------------------------------------------//
    function getPolicyService()
        external
        view
        returns (PolicyService policyService)
    {
        return _policyService;
    }

}