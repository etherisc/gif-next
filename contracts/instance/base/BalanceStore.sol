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

    // used to indicate if the target has been registered as well as when it was last updated (not used externally atm)    
    mapping(NftId nftId => Blocknumber lastUpdatedIn) private _lastUpdatedIn;

    modifier onlyRegisteredTarget(NftId targetNftId) {
        if (!_lastUpdatedIn[targetNftId].gtz()) {
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

    function _registerBalanceTarget(NftId targetNftId) internal {
        if (_lastUpdatedIn[targetNftId].gtz()) {
            revert ErrorBalanceStoreTargetAlreadyRegistered(targetNftId);
        }

        _setLastUpdatedIn(targetNftId);

        emit LogBalanceStoreTargetRegistered(targetNftId);
    }

    //--- fee management ----------------------------------------------------//
    function _increaseFees(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _feeAmount[targetNftId] + amount;
        _feeAmount[targetNftId] = newBalance;

        emit LogBalanceStoreFeesIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    function _decreaseFees(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _feeAmount[targetNftId] - amount;
        _feeAmount[targetNftId] = newBalance;

        emit LogBalanceStoreFeesDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    //--- locked management -------------------------------------------------//
    function _increaseLocked(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _lockedAmount[targetNftId] + amount;
        _lockedAmount[targetNftId] = newBalance;

        emit LogBalanceStoreLockedIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    function _decreaseLocked(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _lockedAmount[targetNftId] - amount;
        _lockedAmount[targetNftId] = newBalance;

        emit LogBalanceStoreLockedDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    //--- balance management ------------------------------------------------//
    function _increaseBalance(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _balanceAmount[targetNftId] + amount;
        _balanceAmount[targetNftId] = newBalance;

        emit LogBalanceStoreBalanceIncreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    function _decreaseBalance(NftId targetNftId, Amount amount) internal onlyRegisteredTarget(targetNftId) returns (Amount newBalance) {
        newBalance = _balanceAmount[targetNftId] - amount;
        _balanceAmount[targetNftId] = newBalance;

        emit LogBalanceStoreBalanceDecreased(targetNftId, amount, newBalance, _lastUpdatedIn[targetNftId]);
        _setLastUpdatedIn(targetNftId);
    }

    //--- internal/private functions ----------------------------------------//
    function _setLastUpdatedIn(NftId targetNftId) internal {
        _lastUpdatedIn[targetNftId] = BlocknumberLib.currentBlocknumber();
    }
}
