// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {Blocknumber, blockNumber} from "../types/Blocknumber.sol";
import {Timestamp, blockTimestamp} from "../types/Timestamp.sol";
import {Version, VersionPart} from "../types/Version.sol";

import {IVersionable} from "./IVersionable.sol";

abstract contract Versionable is Initializable, IVersionable {

    mapping(Version version => VersionInfo info) private _versionHistory;
    Version [] private _versions;


    // controlled activation for controller contract
    constructor() {
        _activate(address(0), msg.sender);
    }

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function initialize(address implementation, address activatedBy, bytes memory initializationData)
        external
        virtual
    { 
        _activate(implementation, activatedBy);
    }
    // TODO mock, delete when implementations are ready
    function activate(address implementation, address activatedBy, bytes memory activatinData) public {}
    function upgrade(address implementation, address activatedBy, bytes memory upgradeData) external {}


    // can only be called once per contract
    // needs bo be called inside the proxy upgrade tx
    function _activate(
        address implementation,
        address activatedBy
    )
        internal
    {
        Version thisVersion = getVersion();
        require(
            !isActivated(thisVersion),
            "ERROR:VRN-001:VERSION_ALREADY_ACTIVATED"
        );
        
        // require increasing version number
        if(_versions.length > 0) {
            Version lastVersion = _versions[_versions.length - 1];
            require(
                thisVersion > lastVersion,
                "ERROR:VRN-002:VERSION_NOT_INCREASING"
            );
        }

        // update version history
        _versions.push(thisVersion);
        _versionHistory[thisVersion] = VersionInfo(
            thisVersion,
            implementation,
            activatedBy,
            blockTimestamp(),
            blockNumber()
        );

        emit LogVersionableActivated(thisVersion, implementation, activatedBy);
    }


    function isActivated(Version _version) public override view returns(bool) {
        return _versionHistory[_version].activatedIn.toInt() > 0;
    }


    function getVersion() public pure virtual returns(Version);


    function getVersionCount() external view override returns(uint256) {
        return _versions.length;
    }


    function getVersion(uint256 idx) external view override returns(Version) {
        return _versions[idx];
    }


    function getVersionInfo(Version _version) external override view returns(VersionInfo memory) {
        return _versionHistory[_version];
    }

    function getInitializedVersion() external view returns(uint64)
    {
        return _getInitializedVersion();
    }
}