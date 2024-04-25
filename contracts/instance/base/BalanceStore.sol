// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Blocknumber, BlocknumberLib} from "../../type/Blocknumber.sol";
import {NftId} from "../../type/NftId.sol";
import {Amount} from "../../type/Amount.sol";

contract BalanceStore {

    error ErrorBalanceStoreTargetAlreadyRegistered(NftId targetNftId);
    error ErrorBalanceStoreTargetNotRegistered(NftId targetNftId);

    event LogBalanceStoreTargetRegistered(NftId targetNftId);

    event LogBalanceStoreFeesIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogBalanceStoreFeesDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogBalanceStoreLockedIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogBalanceStoreLockedDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    event LogBalanceStoreBalanceIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);
    event LogBalanceStoreBalanceDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn);

    mapping(NftId nftId => Amount balance) private _balanceAmount;
    mapping(NftId nftId => Amount locked) private _lockedAmount;
    mapping(NftId nftId => Amount fees) private _feeAmount;
    mapping(NftId nftId => bool isRegistered) private _isRegistered;

    // TODO check if this is made redundant by *Info struct updates
    mapping(NftId nftId => Blocknumber lastUpdatedIn) private _lastUpdatedIn;

    modifier onlyRegisteredTarget(NftId targetNftId) {
        if (!_isRegistered[targetNftId]) {
            revert ErrorBalanceStoreTargetNotRegistered(targetNftId);
        }
        _;
    }

    function getBalanceAmount(NftId targetNftId) external view returns (Amount balanceAmount) { return _balanceAmount[targetNftId]; }
    function getLockedAmount(NftId targetNftId) external view returns (Amount lockedAmount) { return _lockedAmount[targetNftId]; }
    function getFeeAmount(NftId targetNftId) external view returns (Amount feeAmount) { return _feeAmount[targetNftId]; }

    function getAmounts(NftId targetNftId)
        external
        view
        returns (
            Amount balanceAmount,
            Amount lockedAmount,
            Amount feeAmount
        )
    {
        balanceAmount = _balanceAmount[targetNftId];
        lockedAmount = _lockedAmount[targetNftId];
        feeAmount = _feeAmount[targetNftId];
    }

    function _registerTarget(NftId targetNftId) internal {
        if (_isRegistered[targetNftId]) {
            revert ErrorBalanceStoreTargetAlreadyRegistered(targetNftId);
        }

        _isRegistered[targetNftId] = true;
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();

        emit LogBalanceStoreTargetRegistered(targetNftId);
    }

    //--- fee management ----------------------------------------------------//
    function _increaseFees(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _feeAmount[targetNftId] + amount;
        _feeAmount[targetNftId] = newBalance;

        emit LogBalanceStoreFeesIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    function _decreaseFees(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _feeAmount[targetNftId] - amount;
        _feeAmount[targetNftId] = newBalance;

        emit LogBalanceStoreFeesDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    //--- locked management -------------------------------------------------//
    function _increaseLocked(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _lockedAmount[targetNftId] + amount;
        _lockedAmount[targetNftId] = newBalance;

        emit LogBalanceStoreLockedIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    function _decreaseLocked(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _lockedAmount[targetNftId] - amount;
        _lockedAmount[targetNftId] = newBalance;

        emit LogBalanceStoreLockedDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    //--- balance management ------------------------------------------------//
    function _increaseBalance(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _balanceAmount[targetNftId] + amount;
        _balanceAmount[targetNftId] = newBalance;

        emit LogBalanceStoreBalanceIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }

    function _decreaseBalance(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _balanceAmount[targetNftId] - amount;
        _balanceAmount[targetNftId] = newBalance;

        emit LogBalanceStoreBalanceDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }
}
