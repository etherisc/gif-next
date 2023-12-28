// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin5/contracts/proxy/Clones.sol";

import {AccessManagerSimple} from "./AccessManagerSimple.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {Instance} from "./Instance.sol";

contract InstanceService {

    address internal _accessManagerMaster;
    address internal _instanceAccessManagerMaster;
    address internal _instanceMaster;

    function createInstanceClone()
        external 
        returns (
            AccessManagerSimple am, 
            InstanceAccessManager im, 
            Instance i
        )
    {
        am = AccessManagerSimple(Clones.clone(_accessManagerMaster));
        im = InstanceAccessManager(Clones.clone(_instanceAccessManagerMaster));
        i = Instance(Clones.clone(_instanceMaster));
    }

    function setAccessManagerMaster(address accessManager) external {
        _accessManagerMaster = accessManager;
    }

    function setInstanceAccessManagerMaster(address instanceAccessManager) external {
        _instanceAccessManagerMaster = instanceAccessManager;
    }

    function setInstanceMaster(address instance) external {
        _instanceMaster = instance;
    }

    function getAccessManagerMaster() external view returns (address) { return address(_accessManagerMaster); }
    function getInstanceAccessManagerMaster() external view returns (address) { return address(_instanceAccessManagerMaster); }
    function getInstanceMaster() external view returns (address) { return address(_instanceMaster); }
}

