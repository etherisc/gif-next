// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {Blocknumber, blockNumber} from "../types/Blocknumber.sol";
import {Timestamp, blockTimestamp} from "../types/Timestamp.sol";
import {Version, VersionPart} from "../types/Version.sol";

import {IVersionable} from "./IVersionable.sol";

abstract contract VersionableUpgradeable is 
    Initializable,
    IVersionable 
{
    /// @custom:storage-location erc7201:etherisc.storage.Versionable
    struct VersionableStorage {
        mapping(Version version => VersionInfo info) _versionHistory;
        Version [] _versions;
    }

    // keccak256(abi.encode(uint256(keccak256("etherisc.storage.Versionable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VersionableStorageLocation = 0x4f61291a8ac3d020d0a7d919a76b8592aa88385744dee3f8b4f3873b969ed900;
    
    function _getVersionableStorage() private pure returns (VersionableStorage storage $) {
        assembly {
            $.slot := VersionableStorageLocation
        }
    }

    // controlled activation for controller contract
    constructor() {
        _activate(address(0), msg.sender);
    }

    // IMPORTANT this function needs to be implemented by each new version
    // and needs to call internal function call _activate() 
    function activate(address implementation, address activatedBy)
        external
        virtual
        override
        onlyInitialising
    { 
        _activate(implementation, activatedBy);
    }


    // can only be called once per contract
    // needs to be called inside the proxy upgrade tx
    function _activate(
        address implementation,
        address activatedBy
    )
        internal
    {
        VersionableStorage storage $ = _getVersionableStorage();

        Version thisVersion = getVersion();
        require(
            !isActivated(thisVersion),
            "ERROR:VRN-001:VERSION_ALREADY_ACTIVATED"
        );
        
        // require increasing version number
        if($._versions.length > 0) {
            Version lastVersion = $._versions[$._versions.length - 1];
            require(
                thisVersion > lastVersion,
                "ERROR:VRN-002:VERSION_NOT_INCREASING"
            );
        }

        // update version history
        $._versions.push(thisVersion);
        $._versionHistory[thisVersion] = VersionInfo(
            thisVersion,
            implementation,
            activatedBy,
            blockTimestamp(),
            blockNumber()
        );

        emit LogVersionableActivated(thisVersion, implementation, activatedBy);
    }


    function isActivated(Version _version) public override view returns(bool) {
        return _getVersionableStorage()._versionHistory[_version].activatedIn.toInt() > 0;
    }


    function getVersion() public pure virtual returns(Version);


    function getVersionCount() external view override returns(uint256) {
        return _getVersionableStorage()._versions.length;
    }


    function getVersion(uint256 idx) external view override returns(Version) {
        return _getVersionableStorage()._versions[idx];
    }


    function getVersionInfo(Version _version) external override view returns(VersionInfo memory) {
        return _getVersionableStorage()._versionHistory[_version];
    }
}