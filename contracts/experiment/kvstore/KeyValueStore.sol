// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/*

fa = {'from': accounts[0]}
tl = TimestampLib.deploy(fa)
kv = KeyValueStore.deploy(fa)

pk = kv.s2k('policy key 1')
pd = kv.s2b('policy info data 1.a')

rk = kv.s2k('risk key 1')
rd = kv.s2b('risk info data 1.a')

kv.exists(pk)
ptx = kv.create(pk, kv.policy(), pd)
rtx = kv.create(rk, kv.policy(), rd)
kv.exists(pk)
kv.get(pk)

kv.b2s(kv.getData(pk))

pd1b = kv.s2b('b')
ptxb = kv.update(pk, pd1b, True, True) # gas: 48019, 46428

pd1c = kv.s2b('c')
ptxc = kv.update(pk, pd1c, True, True) # gas: 43819, 42228

pd1d = kv.s2b('d')
ptxd = kv.update(pk, pd1d, True, False) # gas: 32655, 32699

pd1e = kv.s2b('e')
ptxe = kv.update(pk, pd1e, False, True) # gas: 34525, 34575

pd1f = kv.s2b('f')
ptxf = kv.update(pk, pd1f, False, False) # gas: 32638, 32682

pd1g = kv.s2b('g')
ptxg = kv.update(pk, pd1f, True, True, True, False) # gas: 



*/

type KeyId is bytes32;

import {ObjectType, RISK, POLICY} from "../../types/ObjectType.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";
import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../../types/Blocknumber.sol";

contract KeyValueStore {

    event LogInfoCreated(bytes32 key, ObjectType objectType, address createdBy);
    event LogInfoUpdated(bytes32 key, ObjectType objectType, address updatedBy, Blocknumber lastUpdateIn);

    struct Metadata {
        ObjectType objectType;
        address updatedBy;
        Blocknumber updatedIn;
        Blocknumber createdIn;
    }

    struct Value {
        Metadata metadata;
        bytes data;
    }

    mapping(bytes32 key => Value value) private _value;
    bytes32[] private _keys;

    // key store functions
    function create(bytes32 key, ObjectType objectType, bytes memory data) public {
        Metadata storage metadata = _value[key].metadata;
        require(metadata.updatedBy == address(0), "ERROR_ALREADY_CREATED");

        address createdBy = msg.sender;
        Blocknumber blocknumber = blockBlocknumber();
        metadata.objectType = objectType;
        metadata.updatedBy = createdBy;
        metadata.updatedIn = blocknumber;
        metadata.createdIn = blocknumber;

        _value[key].data = data;
        _keys.push(key);

        emit LogInfoCreated(key, objectType, createdBy);
    }

    function update(bytes32 key, bytes memory data) public {
        update(key, data, true, true);
    }

    function update(bytes32 key, bytes memory data, bool updateMetadata, bool log) public {
        _value[key].data = data;
        Blocknumber blocknumber = blockBlocknumber();

        if(updateMetadata && log) {
            Metadata storage metadata = _value[key].metadata;
            require(metadata.updatedBy != address(0), "ERROR_NOT_EXISTING");

            if (log) {
                emit LogInfoUpdated(key, metadata.objectType, msg.sender, metadata.updatedIn);
            }

            metadata.updatedBy = msg.sender;
            metadata.updatedIn = blocknumber;
        } else if (log) {
            emit LogInfoUpdated(key, POLICY(), msg.sender, blocknumber);
        }
    }

    function exists(bytes32 key) public view returns (bool) {
        return _value[key].metadata.updatedBy != address(0);
    }

    function get(bytes32 key) public view returns (Value memory value) {
        return _value[key];
    }

    function getMetadata(bytes32 key) public view returns (Metadata memory metadata) {
        return _value[key].metadata;
    }

    function getData(bytes32 key) public view returns (bytes memory data) {
        return _value[key].data;
    }

    function getKeyCount() public view returns (uint256 keyCount) {
        return _keys.length;
    }

    function getKey(uint256 index) public view returns (bytes32 key) {
        return _keys[index];
    }

    function policy() public pure returns (ObjectType) {
        return POLICY();
    }

    function risk() public pure returns (ObjectType) {
        return RISK();
    }

    function s2k(string memory s) public pure returns (bytes32 k) {
        return keccak256(abi.encodePacked(s));
    }

    function s2b(string memory s) public pure returns (bytes memory b) {
        return abi.encode(s);
    }

    function b2s(bytes memory b) public pure returns (string memory s) {
        return abi.decode(b, (string));
    }
}
