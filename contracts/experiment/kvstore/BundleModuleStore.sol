// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/*

from test_brownie.util import contract_from_address
fa = {'from': accounts[0]}
nl = NftIdLib.deploy(fa)
tl = TimestampLib.deploy(fa)
bm = BundleModuleStore.deploy(fa)
kv = contract_from_address(KeyValueStore, bm.getStore())

bi = bm.createBundleInfo(123456, 10**(5+6), kv.s2b('some filter')) # gas: 362979
tx1 = bm.createBundleInfo(bi, fa)

bi.dict()['lockedAmount'] = 42
tx2 = bm.updateBundleInfo(bi, {'from': accounts[1]})

bik32 = tx1.return_value
bik = bm.toKey(bik32)

tx1.info()
tx2.info()

 */

import {NftId, toNftId} from "../../types/NftId.sol";
import {ObjectType, BUNDLE} from "../../types/ObjectType.sol";
import {StateId, ACTIVE} from "../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";

import {IBundle} from "./IBundle.sol";
import {KeyId, KeyMapper} from "./KeyMapper.sol";
import {KvStore2} from "./KvStore2.sol";

contract BundleModuleStore is KeyMapper, IBundle {

    KvStore2 private _store;

    constructor() {
        _store = new KvStore2();
    }

    function createBundleInfo(IBundle.BundleInfo memory info) public returns (bytes32 key) {
        key = toBundleKey32(info.nftId);
        _store.create(key, BUNDLE(), ACTIVE(), abi.encode(info));
    }

    function updateBundleInfo(IBundle.BundleInfo memory info) public {
        bytes32 key = toBundleKey32(info.nftId);
        _store.update(key, ACTIVE(), abi.encode(info));
    }

    function getBundleInfo(bytes32 key) public view returns (IBundle.BundleInfo memory) {
        bytes memory data = _store.getData(key);
        return abi.decode(data, (IBundle.BundleInfo));
    }

    function toBundleKey32(NftId bundleNftId) public pure returns (bytes32 key) {
        return toKey32(BUNDLE(), toKeyId(bundleNftId));
    }

    function toKeyId(NftId nftId) public pure returns (KeyId keyId) {
        uint248 intNftId = nftId.toInt();
        keyId = KeyId.wrap(bytes31(intNftId));
    }

    function createBundleInfo(
        uint256 bundleId,
        uint256 amount,
        bytes calldata filter
    )
        public 
        view
        returns(IBundle.BundleInfo memory info)
    {
        uint256 lifetime = 30 * 24 * 3600;
        return IBundle.BundleInfo(
            toNftId(bundleId),
            toNftId(123456),
            filter,
            amount, // capital amount
            0, // locked amount
            amount, // balance
            blockTimestamp().addSeconds(lifetime), // expiredAt
            zeroTimestamp()); // closedAt
    }

    function getStore() public view returns (KvStore2) {
        return _store;
    }
}