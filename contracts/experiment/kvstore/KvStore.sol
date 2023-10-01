// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/*
fa = {'from': accounts[0]}
tl = TimestampLib.deploy(fa)
kv = KvStore.deploy(fa)
r1 = kv.createRiskInfo(kv.s2b('risk spec 1'))
b1 = kv.createBundleInfo(123456, 10000000, kv.s2b('bundle filter 1'))

(r1k, r1v) = kv.riskInfoToKeyValue(3, r1)

kv.toKey(r1k)

*/

import {NftId, toNftId} from "../../types/NftId.sol";
import {RiskId, toRiskId} from "../../types/RiskId.sol";
import {ObjectType, BUNDLE, RISK} from "../../types/ObjectType.sol";
import {VersionPart} from "../../types/Version.sol";
import {StateId, ACTIVE} from "../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {IBundle} from "./IBundle.sol";
import {IRisk} from "../../instance/module/risk/IRisk.sol";

type KeyId is bytes31;

contract KvStore {

    uint8 public constant TYPE_SHIFT = 31 * 8;
    bytes32 public constant TYPE_MASK = bytes32(bytes1(type(uint8).max)); // first byte in bytes32
    bytes32 public constant ID_MASK = bytes32(~TYPE_MASK); // remaining bytes in bytes32

    struct Key {
        ObjectType objectType;
        KeyId id;
    }

    struct Value {
        VersionPart majorVersion;
        bytes data;
    }

    mapping(bytes32 key => Value value) private _store;
    bytes32[] private _keys;

    function toKey32(RiskId riskId) public pure returns (bytes32 key) {
        uint256 objectType = uint256(ObjectType.unwrap(RISK()));
        uint256 id = uint96(RiskId.unwrap(riskId));
        return bytes32(objectType << TYPE_SHIFT + id);
    }

    function toKey(bytes32 key32) public pure returns (Key memory key) {
        ObjectType objectType = ObjectType.wrap(uint8(uint256(key32 & TYPE_MASK) >> TYPE_SHIFT));
        KeyId id = KeyId.wrap(bytes31(key32 & ID_MASK));
        return Key(objectType, id);
    }

    function toBytes32(uint256 value) public pure returns(bytes32) { return bytes32(value); }

    // key store functions
    function create(bytes32 key, Value memory value) public {
        // add only store
        require(VersionPart.unwrap(_store[key].majorVersion) == 0, "ERROR_KEY_USED");
        _store[key] = value;
        _keys.push(key);
    }

    function update(bytes32 key, Value memory value) public {
        // add only store
        require(VersionPart.unwrap(_store[key].majorVersion) > 0, "ERROR_KEY_UNKNOWN");
        _store[key] = value;
    }

    function getIdMask() public pure returns (bytes32) { return ID_MASK; }
    function getTypeMask() public pure returns (bytes32) { return TYPE_MASK; }

    function get(bytes32 key) public view returns (Value memory value) {
        return _store[key];
    }

    function exists(bytes32 key) public view returns (bool) {
        return VersionPart.unwrap(_store[key].majorVersion) > 0;
    }

    function getKeyCount() public view returns (uint256 keyCount) {
        return _keys.length;
    }

    function getKey(uint256 index) public view returns (bytes32 key) {
        return _keys[index];
    }

    function s2b(string memory s) public pure returns (bytes memory b) {
        return abi.encodePacked(s);
    }

    function b2s(bytes memory b) public pure returns (string memory s) {
        return abi.decode(b, (string));
    }

    // risk related functions

    function keyToRiskId(Key memory key) public pure returns (RiskId id) {
        require(key.objectType == RISK(), "ERROR_NOT_RISK_KEY");
        return RiskId.wrap(bytes12(KeyId.unwrap(key.id)));
    }

    function createRiskInfo(
        bytes memory specification
    )
        public 
        view
        returns(IRisk.RiskInfo memory info)
    {
        RiskId riskId = toRiskId(specification);
        return IRisk.RiskInfo(
            riskId,
            ACTIVE(),
            specification,
            blockTimestamp(), // createdAt
            blockNumber()); // updatedIn
    }

    function riskIdToKey(RiskId riskId) public pure returns(bytes32 key) {
        return keccak256(abi.encode(RISK(), riskId));
    }

    function encodeRiskInfo(IRisk.RiskInfo memory info) public pure returns (bytes memory data) {
        return abi.encode(info);
    }

    function decodeRiskInfo(bytes memory data) public pure returns (IRisk.RiskInfo memory info) {
        return abi.decode(data, (IRisk.RiskInfo));
    }

    function riskInfoToKeyValue(VersionPart majorVersion, IRisk.RiskInfo memory info) public pure returns (bytes32 key, Value memory value) {
        return (
            toKey32(info.id),
            Value(majorVersion, abi.encode(info))
        );
    }

    function valueToRiskInfo(Value memory value) public pure returns (IRisk.RiskInfo memory info) {
        return abi.decode(value.data, (IRisk.RiskInfo));
    }

    // bundle related functions
    function createBundleInfo(
        NftId bundleNftId,
        uint256 amount,
        bytes calldata filter
    )
        public 
        view
        returns(IBundle.BundleInfo memory info)
    {
        uint256 lifetime = 30 * 24 * 3600;
        return IBundle.BundleInfo(
            bundleNftId,
            toNftId(123456),
            filter,
            amount,
            0,
            amount,
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp()); // closedAt
    }

    function nftIdToKey(NftId nftId) public pure returns(bytes32 key) {
        return keccak256(abi.encode(BUNDLE(), nftId));
    }

    function nftIdToKeyPacked(NftId nftId) public pure returns(bytes32 key) {
        return keccak256(abi.encodePacked(BUNDLE(), nftId));
    }

    function bundleInfoToValue(VersionPart majorVersion, IBundle.BundleInfo memory info) public pure returns (Value memory value) {
        return Value(majorVersion, abi.encode(info));
    }

    function valueToBundleInfo(Value memory value) public pure returns (IBundle.BundleInfo memory info) {
        return abi.decode(value.data, (IBundle.BundleInfo));
    }

    function encodeBundleInfo(IBundle.BundleInfo memory info) public pure returns (bytes memory data) {
        return abi.encode(info);
    }

    function decodeBundleInfo(bytes memory data) public pure returns (IBundle.BundleInfo memory info) {
        return abi.decode(data, (IBundle.BundleInfo));
    }
}
