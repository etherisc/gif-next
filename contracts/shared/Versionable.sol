// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Blocknumber, blockNumber} from "../types/Blocknumber.sol";
import {Timestamp, blockTimestamp} from "../types/Timestamp.sol";
import {Version, VersionPart, zeroVersion} from "../types/Version.sol";

import {IVersionable} from "./IVersionable.sol";

abstract contract Versionable is IVersionable {


    mapping(Version version => VersionInfo info) private _versionHistory;
    Version [] private _versions;


    // controlled activation for controller contract
    constructor() {
        _activate(address(0), msg.sender);
    }

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function activate(address implementation, address activatedBy)
        external
        override
    { 
        _activate(implementation, activatedBy);
    }


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
            blockNumber(),
            blockTimestamp()
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
        require(idx < _versions.length, "ERROR:VRN-010:INDEX_TOO_LARGE");
        return _versions[idx];
    }


    function getVersionInfo(Version _version) external override view returns(VersionInfo memory) {
        require(isActivated(_version), "ERROR:VRN-020:VERSION_UNKNOWN");
        return _versionHistory[_version];
    }
}