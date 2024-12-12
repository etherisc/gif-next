# Log events

```



===============
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationCreated(NftId indexed applicationNftId, NftId indexed productNftId, NftId indexed bundleNftId, RiskId riskId, ReferralId referralId, address applicationOwner, Amount sumInsuredAmount, Amount premiumAmount, Seconds lifetime)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationRenewed(NftId indexed policyNftId, NftId indexed bundleNftId)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationAdjusted(NftId indexed applicationNftId, NftId indexed bundleNftId, RiskId indexed riskId, ReferralId referralId, Amount sumInsuredAmount, Seconds lifetime)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationRevoked(NftId indexed applicationNftId)

===============
contracts/product/IClaimService.sol: LogClaimServiceClaimSubmitted(NftId indexed policyNftId, ClaimId indexed claimId, Amount indexed claimAmount)
contracts/product/IClaimService.sol: LogClaimServiceClaimConfirmed(NftId indexed policyNftId, ClaimId indexed claimId, Amount indexed confirmedAmount)
contracts/product/IClaimService.sol: LogClaimServiceClaimDeclined(NftId indexed policyNftId, ClaimId indexed claimId)
contracts/product/IClaimService.sol: LogClaimServiceClaimRevoked(NftId indexed policyNftId, ClaimId indexed claimId)
contracts/product/IClaimService.sol: LogClaimServiceClaimCancelled(NftId indexed policyNftId, ClaimId indexed claimId)
contracts/product/IClaimService.sol: LogClaimServicePayoutCreated(NftId indexed policyNftId, ClaimId indexed claimId, PayoutId indexed payoutId, Amount indexed amount, address beneficiary)
contracts/product/IClaimService.sol: LogClaimServicePayoutProcessed(NftId indexed policyNftId, PayoutId indexed payoutId, Amount indexed amount)
contracts/product/IClaimService.sol: LogClaimServicePayoutCancelled(NftId indexed policyNftId, PayoutId indexed payoutId)

===============
contracts/product/IPolicyService.sol: LogPolicyServicePolicyCreated(NftId indexed policyNftId, Amount indexed premiumAmount, Timestamp indexed activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyDeclined(NftId indexed policyNftId)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyPremiumCollected(NftId indexed policyNftId, NftId indexed productNftId, Amount indexed premiumAmount, Timestamp activateAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyActivated(NftId indexed policyNftId, Timestamp indexed activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyActivationUpdated(NftId indexed policyNftId, Timestamp indexed activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyExpirationUpdated(NftId indexed policyNftId, Timestamp indexed expiredAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyClosed(NftId indexed policyNftId)

===============
contracts/product/IRiskService.sol: LogRiskServiceRiskCreated(NftId indexed productNftId, RiskId indexed riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskUpdated(NftId indexed productNftId, RiskId indexed riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskLocked(NftId indexed productNftId, RiskId indexed riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskUnlocked(NftId indexed productNftId, RiskId indexed riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskClosed(NftId indexed productNftId, RiskId indexed riskId)

===============
contracts/registry/ChainNft.sol: LogChainNftInterceptorAddress(uint256 indexed tokenId, address indexed interceptor)

===============
contracts/registry/IRegistry.sol: LogRegistryObjectRegistered(NftId indexed nftId, NftId indexed parentNftId, ObjectType indexed objectType, bool isInterceptor, address objectAddress, address initialOwner)
contracts/registry/IRegistry.sol: LogRegistryServiceRegistered(NftId indexed nftId, VersionPart indexed majorVersion, ObjectType indexed domain)
contracts/registry/IRegistry.sol: LogRegistryChainRegistryRegistered(NftId indexed nftId, uint256 indexed chainId, address indexed chainRegistryAddress)

===============
contracts/registry/ReleaseAdmin.sol: LogReleaseAdminReleaseLocked(VersionPart indexed release, bool indexed locked)
contracts/registry/ReleaseAdmin.sol: LogReleaseAdminServiceLocked(VersionPart indexed release, address indexed service, bool indexed locked)

===============
contracts/registry/ReleaseRegistry.sol: LogReleaseCreation(IAccessAdmin indexed admin, VersionPart indexed release, bytes32 indexed salt)
contracts/registry/ReleaseRegistry.sol: LogReleaseActivation(VersionPart indexed release)
contracts/registry/ReleaseRegistry.sol: LogReleaseDisabled(VersionPart indexed release)
contracts/registry/ReleaseRegistry.sol: LogReleaseEnabled(VersionPart indexed release)

===============
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenRegistered(ChainId indexed chainId, address indexed token, string indexed symbol, uint256 decimals)
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenGlobalStateSet(ChainId indexed chainId, address indexed token, bool indexed active)
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenStateSet(ChainId indexed chainId, address indexed token, bool indexed active, VersionPart release)

===============
contracts/shared/IComponentService.sol: LogComponentServiceComponentLocked(address component, bool locked)
contracts/shared/IComponentService.sol: LogComponentServiceTokenHandlerDeployed(NftId componentNftId, address tokenHandler, address token)
contracts/shared/IComponentService.sol: LogComponentServiceComponentRegistered(NftId instanceNftId, NftId componentNftId, ObjectType componentType, address component, address token, address initialOwner)
contracts/shared/IComponentService.sol: LogComponentServiceComponentFeesWithdrawn(NftId componentNftId, address recipient, address token, Amount withdrawnAmount)
contracts/shared/IComponentService.sol: LogComponentServiceProductFeesUpdated(NftId productNftId)
contracts/shared/IComponentService.sol: LogComponentServiceDistributionFeesUpdated(NftId distributionNftId)
contracts/shared/IComponentService.sol: LogComponentServicePoolFeesUpdated(NftId poolNftId)
contracts/shared/IComponentService.sol: LogComponentServiceUpdateFee(NftId nftId, string feeName, UFixed previousFractionalFee, Amount previousFixedFee, UFixed newFractionalFee, Amount newFixedFee)

===============
contracts/shared/INftOwnable.sol: LogNftOwnableNftLinkedToAddress(NftId nftId, address owner)

===============
contracts/shared/TokenHandler.sol: LogTokenHandlerWalletAddressChanged(NftId componentNftId, address oldWallet, address newWallet)
contracts/shared/TokenHandler.sol: LogTokenHandlerWalletTokensTransferred(NftId componentNftId, address oldWallet, address newWallet, Amount amount)
contracts/shared/TokenHandler.sol: LogTokenHandlerTokenApproved(NftId nftId, address tokenHandler, address token, Amount amount, bool isMaxAmount)
contracts/shared/TokenHandler.sol: LogTokenHandlerTokenTransfer(address token, address from, address to, Amount amount)

===============
contracts/staking/IStaking.sol: LogStakingTokenHandlerDeployed(NftId componentNftId, address tokenHandler, address token)
contracts/staking/IStaking.sol: LogStakingStakingRateSet(ChainId chainId, address token, UFixed oldStakingRate, UFixed newStakingRate, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingStakingServiceSet(address stakingService, VersionPart release, address oldStakingService)
contracts/staking/IStaking.sol: LogStakingStakingReaderSet(address stakingReader, address oldStakingReader)
contracts/staking/IStaking.sol: LogStakingTargetHandlerSet(address targetManager, address oldTargetHandler)
contracts/staking/IStaking.sol: LogStakingTokenHandlerApproved(address token, Amount approvalAmount, Amount oldApprovalAmount)
contracts/staking/IStaking.sol: LogStakingTokenAdded(ChainId chainId, address token)
contracts/staking/IStaking.sol: LogStakingTargetTokenAdded(NftId targetNftId, address token)
contracts/staking/IStaking.sol: LogStakingTvlIncreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTvlDecreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingSupportInfoSet(ObjectType objectType, bool isSupported, bool allowNewTargets, bool allowCrossChain, Amount minStakingAmount, Amount maxStakingAmount, Seconds minLockingPeriod, Seconds maxLockingPeriod, UFixed minRewardRate, UFixed maxRewardRate, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetCreated(NftId targetNftId, ObjectType objectType, Seconds lockingPeriod, UFixed rewardRate)
contracts/staking/IStaking.sol: LogStakingLimitsSet(NftId targetNftId, Amount marginAmount, Amount hardLimitAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLimitsUpdated(NftId targetNftId, Amount marginAmount, Amount hardLimitAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLimitUpdated(NftId targetNftId, Amount limitAmount, Amount hardLimitAmount, Amount requiredStakeAmount, Amount actualStakeAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLockingPeriodSet(NftId targetNftId, Seconds oldLockingPeriod, Seconds newLockingPeriod, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed newRewardRate, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetMaxStakedAmountSet(NftId targetNftId, Amount stakeLimitAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLimitsSet(NftId targetNftId, Amount stakeLimitAmount, Amount marginAmount, Amount limitAmount)
contracts/staking/IStaking.sol: LogStakingRewardReservesRefilled(NftId targetNftId, Amount dipAmount, address targetOwner, Amount reserveBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingRewardReservesWithdrawn(NftId targetNftId, Amount dipAmount, address targetOwner, Amount reserveBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingRewardReservesSpent(NftId targetNftId, Amount dipAmount, Amount reserveBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingStakeCreated(NftId stakeNftId, NftId targetNftId, Amount stakeAmount, Timestamp lockedUntil, address stakeOwner)
contracts/staking/IStaking.sol: LogStakingStakeRewardsUpdated(NftId stakeNftId, Amount rewardIncrementAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingRewardsRestaked(NftId stakeNftId, Amount restakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingStaked(NftId stakeNftId, Amount stakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingUnstaked(NftId stakeNftId, Amount unstakedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingRewardsClaimed(NftId stakeNftId, Amount claimedAmount, Amount stakeBalance, Amount rewardBalance, Timestamp lockedUntil, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingStakeRestaked(NftId stakeNftId, NftId targetNftId, Amount stakeAmount, address owner, NftId oldStakeNftId)

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
