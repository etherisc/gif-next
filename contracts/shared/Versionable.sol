// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin5/contracts/proxy/utils/Initializable.sol";

import {Blocknumber, blockNumber} from "../types/Blocknumber.sol";
import {Timestamp, blockTimestamp} from "../types/Timestamp.sol";
import {Version, VersionPart, VersionLib} from "../types/Version.sol";

import {IVersionable} from "./IVersionable.sol";



abstract contract Versionable is 
    Initializable,
    IVersionable 
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.shared.Versionable.sol")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VERSIONABLE_LOCATION_V1 = 0x4f61291a8ac3d020d0a7d919a76b8592aa88385744dee3f8b4f3873b969ed900;


    /// @custom:storage-location erc7201:gif-next.contracts.shared.Versionable.sol
    struct VersionableStorage {
        mapping(Version version => VersionInfo info) _versionHistory;
        Version [] _versions;
        Version _v1;
    }


    constructor() {
        _disableInitializers();
    }
    // TODO write test where new version of private _updateVersionHistory is added and used... 
    function initialize(
        address implementation,
        address activatedBy,
        bytes memory data
    )
        public
        initializer
    {
        _updateVersionHistory(implementation, activatedBy);
        _initialize(activatedBy, data);
    }

    // TODO activatedBy MUST ALWAYS be an owner?
    function upgrade(
        address implementation,
        address activatedBy,
        bytes memory data
    )
        external
        reinitializer(VersionLib.toUint64(getVersion()))
    {
        _updateVersionHistory(implementation, activatedBy);
        _upgrade(data);
    }

    function isInitialized(Version _version) public override view returns(bool) {
        return _getVersionableStorage()._versionHistory[_version].activatedIn.toInt() > 0;
    }

    function getVersion() public pure virtual returns(Version);

    function getVersionCount() public view override returns(uint256) {
        return _getVersionableStorage()._versions.length;
    }

    function getVersion(uint256 idx) public view override returns(Version) {
        return _getVersionableStorage()._versions[idx];
    }

    function getVersionInfo(Version _version) public override view returns(VersionInfo memory) {
        return _getVersionableStorage()._versionHistory[_version];
    }

    function getInitializedVersion() public view returns(uint64) {
        return _getInitializedVersion();
    }



    // IMPORTANT each version must implement this function 
    // each implementation MUST use onlyInitialising modifier
    // each implementation MUST call intializers of all base contracts...
    function _initialize(address owner, bytes memory data) 
        internal
        onlyInitializing
        virtual 
    {
        revert();
    }


    // IMPORTANT each version except version "1" must implement this function 
    // each implementation MUST use onlyInitialising modifier
    function _upgrade(bytes memory data)
        internal
        onlyInitializing
        virtual
    {
        revert();
    }

    function _getVersionableStorage() private pure returns (VersionableStorage storage $) {
        assembly {
            $.slot := VERSIONABLE_LOCATION_V1
        }
    }

    // can only be called once per contract
    // needs to be called inside the proxy upgrade tx
    // TODO run reinitializer(version().toUint64()) modifier after "version()" is checked, 
    function _updateVersionHistory(
        address implementation,
        address activatedBy
    )
        private
        onlyInitializing
    {
        VersionableStorage storage $ = _getVersionableStorage();

        uint64 version = _getInitializedVersion();

        Version thisVersion = getVersion();

        if(version == 1) {
            // thisVersion is alias to version "1"
            $._v1 = thisVersion;
        }
        else {
            require(thisVersion > $._v1, "INVALID VERSION");
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

        emit LogVersionableInitialized(thisVersion, implementation, activatedBy);
    }
}