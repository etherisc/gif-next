# Log events

```


===============
contracts/staking/IStakingService.sol: LogStakingServiceProtocolTargetRegistered(NftId protocolNftId)
contracts/staking/IStakingService.sol: LogStakingServiceInstanceTargetRegistered(NftId instanceNftId, Seconds initialLockingPeriod, UFixed initialRewardRate)
contracts/staking/IStakingService.sol: LogStakingServiceRewardReservesIncreased(NftId targetNftId, address rewardProvider, Amount dipAmount, Amount newBalance)
contracts/staking/IStakingService.sol: LogStakingServiceRewardReservesDecreased(NftId targetNftId, address targetOwner, Amount dipAmount, Amount newBalance)
contracts/staking/IStakingService.sol: LogStakingServiceStakeCreated(NftId stakeNftId, NftId targetNftId, address stakeOwner)

===============
contracts/staking/TargetHandler.sol: LogTargetHandlerUpdateTriggersSet(uint16 tvlUpdatesTrigger, UFixed minTvlRatioTrigger, Blocknumber lastUpdateIn)

===============
contracts/upgradeability/ProxyManager.sol: LogProxyManagerVersionableDeployed(address proxy, address initialImplementation)
contracts/upgradeability/ProxyManager.sol: LogProxyManagerVersionableUpgraded(address proxy, address upgradedImplementation)

===============
contracts/examples/flight/FlightLib.sol: LogFlightProductErrorUnprocessableStatus(RequestId requestId, RiskId riskId, bytes1 status)
contracts/examples/flight/FlightLib.sol: LogFlightProductErrorUnexpectedStatus(RequestId requestId, RiskId riskId, bytes1 status, int256 delayMinutes)

===============
contracts/examples/flight/FlightOracle.sol: LogFlightOracleRequestReceived(RequestId requestId, NftId requesterId)
contracts/examples/flight/FlightOracle.sol: LogFlightOracleResponseSent(RequestId requestId, bytes1 status, int256 delay)
contracts/examples/flight/FlightOracle.sol: LogFlightOracleRequestCancelled(RequestId requestId)

===============
contracts/examples/flight/FlightProduct.sol: LogFlightPolicyPurchased(NftId policyNftId, string flightData, Amount premiumAmount)
contracts/examples/flight/FlightProduct.sol: LogFlightPolicyClosed(NftId policyNftId, Amount payoutAmount)
contracts/examples/flight/FlightProduct.sol: LogFlightStatusProcessed(RequestId requestId, RiskId riskId, bytes1 status, int256 delayMinutes, uint8 payoutOption)
contracts/examples/flight/FlightProduct.sol: LogFlightPoliciesProcessed(RiskId riskId, uint8 payoutOption, uint256 policiesProcessed, uint256 policiesRemaining)

===============
contracts/examples/flight/originalV1.sol: LogRequestFlightRatings(uint256 requestId, bytes32 carrierFlightNumber, uint256 departureTime, uint256 arrivalTime, bytes32 riskId)
contracts/examples/flight/originalV1.sol: LogRequestFlightStatus(uint256 requestId, uint256 arrivalTime, bytes32 carrierFlightNumber, bytes32 departureYearMonthDay)
contracts/examples/flight/originalV1.sol: LogPayoutTransferred(bytes32 bpKey, uint256 claimId, uint256 payoutId, uint256 amount)
contracts/examples/flight/originalV1.sol: LogError(string error, uint256 index, uint256 stored, uint256 calculated)
contracts/examples/flight/originalV1.sol: LogUnprocessableStatus(bytes32 bpKey, uint256 requestId)
contracts/examples/flight/originalV1.sol: LogPolicyExpired(bytes32 bpKey)
contracts/examples/flight/originalV1.sol: LogRequestPayment(bytes32 bpKey, uint256 requestId)
contracts/examples/flight/originalV1.sol: LogUnexpectedStatus(bytes32 bpKey, uint256 requestId, bytes1 status, int256 delay, address customer)
contracts/examples/flight/originalV1.sol: LogCallback(bytes32 _bytes, bytes _data)

===============
contracts/examples/unpermissioned/SimpleOracle.sol: LogSimpleOracleRequestReceived(RequestId requestId, NftId requesterId, bool synchronous, string requestText)
contracts/examples/unpermissioned/SimpleOracle.sol: LogSimpleOracleCancellingReceived(RequestId requestId)
contracts/examples/unpermissioned/SimpleOracle.sol: LogSimpleOracleAsyncResponseSent(RequestId requestId, string responseText)
contracts/examples/unpermissioned/SimpleOracle.sol: LogSimpleOracleSyncResponseSent(RequestId requestId, string responseText)

===============
contracts/examples/unpermissioned/SimpleProduct.sol: LogSimpleProductRequestAsyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength)
contracts/examples/unpermissioned/SimpleProduct.sol: LogSimpleProductRequestSyncFulfilled(RequestId requestId, string responseText, uint256 responseDataLength)

===============
contracts/instance/base/BalanceStore.sol: LogBalanceStoreTargetRegistered(NftId targetNftId)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreFeesIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreFeesDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreLockedIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreLockedDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreBalanceIncreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)
contracts/instance/base/BalanceStore.sol: LogBalanceStoreBalanceDecreased(NftId targetNftId, Amount addedAmount, Amount newBalance, Blocknumber lastUpdatedIn)

===============
contracts/instance/base/ObjectSet.sol: LogObjectSetInitialized(address instance)
```
