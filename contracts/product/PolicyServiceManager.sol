// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IVersionable} from "../upgradeability/IVersionable.sol";
import {ProxyManager} from "../upgradeability/ProxyManager.sol";
import {PolicyService} from "./PolicyService.sol";

contract PolicyServiceManager is ProxyManager {

    PolicyService private _policyService;

    /// @dev initializes proxy manager with product service implementation 
    constructor(
        address authority, 
        address registryAddress,
        bytes32 salt
    ) 
        ProxyManager(registryAddress)
    {
        PolicyService svc = new PolicyService{salt: salt}();
        bytes memory data = abi.encode(registryAddress, address(this), authority);
        IVersionable versionable = deployDetermenistic(
            address(svc), 
            data,
            salt);

        _policyService = PolicyService(address(versionable));
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