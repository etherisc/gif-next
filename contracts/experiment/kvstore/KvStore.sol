// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId, toNftId} from "../../types/NftId.sol";
import {RiskId, toRiskId} from "../../types/RiskId.sol";
import {ObjectType, BUNDLE, RISK} from "../../types/ObjectType.sol";
import {StateId, ACTIVE} from "../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {IBundle} from "../../instance/module/bundle/IBundle.sol";
import {IRisk} from "../../instance/module/risk/IRisk.sol";

contract KvStore {

    struct Value {
        ObjectType dataType;
        bytes data;
    }

    mapping(bytes32 key => Value value) private _store;
    bytes32[] private _keys;

    // key store functions
    function save(bytes32 key, Value memory value) public {
        // add only store
        require(ObjectType.unwrap(_store[key].dataType) == 0, "ERROR_KEY_USED");
        _store[key] = value;
        _keys.push(key);
    }

    function load(bytes32 key) public view returns (Value memory value) {
        return _store[key];
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

    function riskInfoToKeyValue(IRisk.RiskInfo memory info) public pure returns (bytes32 key, Value memory value) {
        return (
            keccak256(abi.encode(RISK(), info.id)),
            Value(RISK(), abi.encode(info))
        );
    }

    function riskInfoToValue(IRisk.RiskInfo memory info) public pure returns (Value memory value) {
        return Value(RISK(), abi.encode(info));
    }

    function valueToRiskInfo(Value memory value) public pure returns (IRisk.RiskInfo memory info) {
        require(value.dataType == RISK(), "ERROR_NOT_RISK");
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
            ACTIVE(),
            filter,
            amount,
            0,
            amount,
            blockTimestamp(), // createdAt
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp(), // closedAt
            blockNumber()); // updatedIn
    }

    function nftIdToKey(NftId nftId) public pure returns(bytes32 key) {
        return keccak256(abi.encode(BUNDLE(), nftId));
    }

    function nftIdToKeyPacked(NftId nftId) public pure returns(bytes32 key) {
        return keccak256(abi.encodePacked(BUNDLE(), nftId));
    }

    function bundleInfoToValue(IBundle.BundleInfo memory info) public pure returns (Value memory value) {
        return Value(BUNDLE(), abi.encode(info));
    }

    function valueToBundleInfo(Value memory value) public pure returns (IBundle.BundleInfo memory info) {
        require(value.dataType == BUNDLE(), "ERROR_NOT_BUNDLE");
        return abi.decode(value.data, (IBundle.BundleInfo));
    }

    function encodeBundleInfo(IBundle.BundleInfo memory info) public pure returns (bytes memory data) {
        return abi.encode(info);
    }

    function decodeBundleInfo(bytes memory data) public pure returns (IBundle.BundleInfo memory info) {
        return abi.decode(data, (IBundle.BundleInfo));
    }
}
