# Log events

```
===============
contracts/accounting/IAccountingService.sol: LogAccountingServiceBalanceChanged(NftId nftId, Amount amount, Amount feeAmount, bool increase, ObjectType objectType)

===============
contracts/authorization/AccessManagerCloneable.sol: LogAccessManagerLocked(address accessManager, bool locked)

===============
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleCreated(string admin, RoleId roleId, TargetType targetType, RoleId roleAdminId, string name)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminTargetCreated(string admin, string name, bool managed, address target, RoleId roleId)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleActivatedSet(string admin, RoleId roleId, bool active, Blocknumber lastUpdateIn)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleGranted(string admin, address account, string roleName)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleRevoked(string admin, address account, string roleName)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminTargetLockedSet(string admin, address target, bool locked, Blocknumber lastUpdateIn)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminFunctionGranted(string admin, address target, string func, Blocknumber lastUpdateIn)

===============
contracts/distribution/IDistributionComponent.sol: LogDistributorUpdated(address to, address operator)

===============
contracts/distribution/IDistributionService.sol: LogDistributionServiceCommissionWithdrawn(NftId distributorNftId, address recipient, address tokenAddress, Amount amount)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorTypeCreated(NftId distributionNftId, string name, UFixed commissionPercentage)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorCreated(NftId distributionNftId, NftId distributorNftId, DistributorType distributorType, address distributor)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorTypeChanged(NftId distributorNftId, DistributorType oldDistributorType, DistributorType newDistributorType)
contracts/distribution/IDistributionService.sol: LogDistributionServiceReferralCreated(NftId distributionNftId, NftId distributorNftId, ReferralId referralId, string code, UFixed discountPercentage, uint32 maxReferrals, Timestamp expiryAt)
contracts/distribution/IDistributionService.sol: LogDistributionServiceReferralProcessed(NftId distributionNftId, NftId distributorNftId, ReferralId referralId, uint32 usedReferrals)
contracts/distribution/IDistributionService.sol: LogDistributionServiceSaleProcessed(NftId distributionNftId, ReferralId referralId, Amount premium, Amount distributionOwnerFee)
contracts/distribution/IDistributionService.sol: LogDistributionServiceSaleProcessedWithReferral(NftId distributionNftId, NftId distributorNftId, ReferralId referralId, uint32 numPoliciesSold, Amount premium, Amount distributionOwnerFee, Amount commissionAmount)

===============
contracts/instance/BundleSet.sol: LogBundleSetPolicyLinked(NftId bundleNftId, NftId policyNftId)
contracts/instance/BundleSet.sol: LogBundleSetPolicyUnlinked(NftId bundleNftId, NftId policyNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleAdded(NftId poolNftId, NftId bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleUnlocked(NftId poolNftId, NftId bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleLocked(NftId poolNftId, NftId bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleClosed(NftId poolNftId, NftId bundleNftId)

===============
contracts/instance/IBaseStore.sol: LogBaseStoreMetadataCreated(Key32 key, ObjectType objectType, StateId state)
contracts/instance/IBaseStore.sol: LogBaseStoreMetadataUpdated(Key32 key, StateId oldState, StateId newState)

===============
contracts/instance/IInstance.sol: LogInstanceCustomRoleCreated(RoleId roleId, string roleName, RoleId adminRoleId, uint32 maxMemberCount)
contracts/instance/IInstance.sol: LogInstanceCustomRoleActiveSet(RoleId roleId, bool active, address caller)
contracts/instance/IInstance.sol: LogInstanceCustomRoleGranted(RoleId roleId, address account, address caller)
contracts/instance/IInstance.sol: LogInstanceCustomRoleRevoked(RoleId roleId, address account, address caller)
contracts/instance/IInstance.sol: LogInstanceCustomTargetCreated(address target, RoleId targetRoleId, string name)
contracts/instance/IInstance.sol: LogInstanceTargetLocked(address target, bool locked)
contracts/instance/IInstance.sol: LogInstanceCustomTargetFunctionRoleSet(address target, bytes4[] selectors, RoleId roleId)

===============
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceLocked(NftId instanceNftId, bool locked)
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceCreated(NftId instanceNftId, address instance)
contracts/instance/IInstanceService.sol: LogInstanceServiceMasterInstanceRegistered(NftId masterInstanceNftId, address masterInstance, address masterInstanceAdmin, address masterAccessManager, address masterInstanceReader, address masterInstanceBundleSet, address masterInstanceRiskSet, address masterInstanceStore, address masterProductStore)
contracts/instance/IInstanceService.sol: LogInstanceServiceMasterInstanceReaderUpgraded(NftId instanceNfId, address newInstanceReader)
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceReaderUpgraded(NftId instanceNfId, address newInstanceReader)

===============
contracts/instance/InstanceStore.sol: LogProductStoreComponentInfoCreated(NftId componentNftId, StateId state, address createdby, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreComponentInfoUpdated(NftId componentNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStorePoolInfoCreated(NftId poolNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStorePoolInfoUpdated(NftId poolNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorTypeInfoCreated(DistributorType distributorType, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorTypeInfoUpdated(DistributorType distributorType, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorInfoCreated(NftId distributorNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorInfoUpdated(NftId distributorNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreReferralInfoCreated(ReferralId referralId, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreReferralInfoUpdated(ReferralId referralId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreBundleInfoCreated(NftId bundleNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreBundleInfoUpdated(NftId bundleNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreRequestInfoCreated(RequestId requestId, StateId state, address createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreRequestInfoUpdated(RequestId requestId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)

===============
contracts/instance/ProductStore.sol: LogProductStoreProductInfoCreated(NftId productNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreProductInfoUpdated(NftId productNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreFeeInfoCreated(NftId productNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreFeeInfoUpdated(NftId productNftId, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreRiskInfoCreated(RiskId riskId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreRiskInfoUpdated(RiskId riskId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePolicyInfoCreated(NftId policyNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePolicyInfoUpdated(NftId policyNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePremiumInfoCreated(NftId policyNftId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePremiumInfoUpdated(NftId policyNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreClaimInfoCreated(NftId policyNftId, ClaimId claimId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreClaimInfoUpdated(NftId policyNftId, ClaimId claimId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePayoutInfoCreated(NftId policyNftId, PayoutId payoutId, StateId state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePayoutInfoUpdated(NftId policyNftId, PayoutId payoutId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)

===============
contracts/instance/RiskSet.sol: LogRiskSetPolicyLinked(RiskId riskId, NftId policyNftId)
contracts/instance/RiskSet.sol: LogRiskSetPolicyUnlinked(RiskId riskId, NftId policyNftId)
contracts/instance/RiskSet.sol: LogRiskSetRiskAdded(NftId productNftId, RiskId riskId)
contracts/instance/RiskSet.sol: LogRiskSetRiskActive(NftId poolNftId, RiskId riskId)
contracts/instance/RiskSet.sol: LogRiskSetRiskPaused(NftId poolNftId, RiskId riskId)

===============
contracts/oracle/IOracleService.sol: LogOracleServiceRequestCreated(RequestId requestId, NftId requesterNftId, NftId oracleNftId, Timestamp expiryAt)
contracts/oracle/IOracleService.sol: LogOracleServiceResponseProcessed(RequestId requestId, NftId oracleNftId)
contracts/oracle/IOracleService.sol: LogOracleServiceDeliveryFailed(RequestId requestId, address requesterAddress, string functionSignature)
contracts/oracle/IOracleService.sol: LogOracleServiceResponseResent(RequestId requestId, NftId requesterNftId)
contracts/oracle/IOracleService.sol: LogOracleServiceRequestCancelled(RequestId requestId, NftId requesterNftId)

===============
contracts/pool/IBundleService.sol: LogBundleServiceBundleCreated(NftId bundleNftId, NftId poolNftId, Seconds lifetime, Amount fixedFee, UFixed fractionalFee)
contracts/pool/IBundleService.sol: LogBundleServiceBundleClosed(NftId bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleLocked(NftId bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleUnlocked(NftId bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleExtended(NftId bundleNftId, Seconds lifetimeExtension, Timestamp extendedExpiredAt)
contracts/pool/IBundleService.sol: LogBundleServiceBundleFeeUpdated(NftId bundleNftId, Amount fixedFee, UFixed fractionalFee)
contracts/pool/IBundleService.sol: LogBundleServiceCollateralLocked(NftId bundleNftId, NftId policyNftId, Amount collateralAmount)
contracts/pool/IBundleService.sol: LogBundleServiceCollateralReleased(NftId bundleNftId, NftId policyNftId, Amount collateralAmount)
contracts/pool/IBundleService.sol: LogBundleServiceBundleStaked(NftId bundleNftId, Amount amount)
contracts/pool/IBundleService.sol: LogBundleServiceBundleUnstaked(NftId bundleNftId, Amount amount)

===============
contracts/pool/IPoolComponent.sol: LogPoolVerifiedByPool(address pool, NftId applicationNftId, Amount collateralizationAmount)

===============
contracts/pool/IPoolService.sol: LogPoolServiceMaxBalanceAmountUpdated(NftId poolNftId, Amount previousMaxCapitalAmount, Amount currentMaxCapitalAmount)
contracts/pool/IPoolService.sol: LogPoolServiceWalletFunded(NftId poolNftId, address poolOwner, Amount amount)
contracts/pool/IPoolService.sol: LogPoolServiceWalletDefunded(NftId poolNftId, address poolOwner, Amount amount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleCreated(NftId instanceNftId, NftId poolNftId, NftId bundleNftId)
contracts/pool/IPoolService.sol: LogPoolServiceBundleClosed(NftId instanceNftId, NftId poolNftId, NftId bundleNftId, Amount balanceAmount, Amount feeAmount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleStaked(NftId instanceNftId, NftId poolNftId, NftId bundleNftId, Amount amount, Amount netAmount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleUnstaked(NftId instanceNftId, NftId poolNftId, NftId bundleNftId, Amount amount, Amount netAmount)
contracts/pool/IPoolService.sol: LogPoolServiceFeesWithdrawn(NftId bundleNftId, address recipient, address tokenAddress, Amount amount)
contracts/pool/IPoolService.sol: LogPoolServiceProcessFundedClaim(NftId policyNftId, ClaimId claimId, Amount availableAmount)
contracts/pool/IPoolService.sol: LogPoolServiceApplicationVerified(NftId poolNftId, NftId bundleNftId, NftId applicationNftId, Amount totalCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceCollateralLocked(NftId poolNftId, NftId bundleNftId, NftId applicationNftId, Amount totalCollateralAmount, Amount lockedCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceCollateralReleased(NftId bundleNftId, NftId policyNftId, Amount remainingCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceSaleProcessed(NftId poolNftId, NftId bundleNftId, Amount bundleNetAmount, Amount bundleFeeAmount, Amount poolFeeAmount)
contracts/pool/IPoolService.sol: LogPoolServicePayoutProcessed(NftId poolNftId, NftId bundleNftId, NftId policyNftId, PayoutId payoutId, Amount netPayoutAmount, Amount processingFeeAmount, address payoutBeneficiary)

===============
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationCreated(NftId applicationNftId, NftId productNftId, NftId bundleNftId, RiskId riskId, ReferralId referralId, address applicationOwner, Amount sumInsuredAmount, Amount premiumAmount, Seconds lifetime)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationRenewed(NftId policyNftId, NftId bundleNftId)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationAdjusted(NftId applicationNftId, NftId bundleNftId, RiskId riskId, ReferralId referralId, Amount sumInsuredAmount, Seconds lifetime)
contracts/product/IApplicationService.sol: LogApplicationServiceApplicationRevoked(NftId applicationNftId)

===============
contracts/product/IClaimService.sol: LogClaimServiceClaimSubmitted(NftId policyNftId, ClaimId claimId, Amount claimAmount)
contracts/product/IClaimService.sol: LogClaimServiceClaimConfirmed(NftId policyNftId, ClaimId claimId, Amount confirmedAmount)
contracts/product/IClaimService.sol: LogClaimServiceClaimDeclined(NftId policyNftId, ClaimId claimId)
contracts/product/IClaimService.sol: LogClaimServiceClaimRevoked(NftId policyNftId, ClaimId claimId)
contracts/product/IClaimService.sol: LogClaimServiceClaimCancelled(NftId policyNftId, ClaimId claimId)
contracts/product/IClaimService.sol: LogClaimServicePayoutCreated(NftId policyNftId, PayoutId payoutId, Amount amount, address beneficiary)
contracts/product/IClaimService.sol: LogClaimServicePayoutProcessed(NftId policyNftId, PayoutId payoutId, Amount amount)
contracts/product/IClaimService.sol: LogClaimServicePayoutCancelled(NftId policyNftId, PayoutId payoutId)

===============
contracts/product/IPolicyService.sol: LogPolicyServicePolicyCreated(NftId policyNftId, Amount premiumAmount, Timestamp activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyDeclined(NftId policyNftId)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyPremiumCollected(NftId policyNftId, NftId productNftId, Amount premiumAmount, Timestamp activateAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyActivated(NftId policyNftId, Timestamp activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyActivatedUpdated(NftId policyNftId, Timestamp activatedAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyExpirationUpdated(NftId policyNftId, Timestamp expiredAt)
contracts/product/IPolicyService.sol: LogPolicyServicePolicyClosed(NftId policyNftId)

===============
contracts/product/IRiskService.sol: LogRiskServiceRiskCreated(NftId productNftId, RiskId riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskUpdated(NftId productNftId, RiskId riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskLocked(NftId productNftId, RiskId riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskUnlocked(NftId productNftId, RiskId riskId)
contracts/product/IRiskService.sol: LogRiskServiceRiskClosed(NftId productNftId, RiskId riskId)

===============
contracts/registry/ChainNft.sol: LogTokenInterceptorAddress(uint256 tokenId, address interceptor)

===============
contracts/registry/IRegistry.sol: LogRegistryObjectRegistered(NftId nftId, NftId parentNftId, ObjectType objectType, bool isInterceptor, address objectAddress, address initialOwner)
contracts/registry/IRegistry.sol: LogRegistryServiceRegistered(NftId nftId, VersionPart majorVersion, ObjectType domain)
contracts/registry/IRegistry.sol: LogRegistryChainRegistryRegistered(NftId nftId, uint256 chainId, address chainRegistryAddress)

===============
contracts/registry/RegistryAuthorization.sol: LogAccessAdminDebug(string message, string custom, uint256 value)

===============
contracts/registry/ReleaseAdmin.sol: LogReleaseAdminReleaseLockChanged(VersionPart release, bool locked)
contracts/registry/ReleaseAdmin.sol: LogReleaseAdminServiceLockChanged(VersionPart release, address service, bool locked)

===============
contracts/registry/ReleaseRegistry.sol: LogReleaseCreation(IAccessAdmin admin, VersionPart release, bytes32 salt)
contracts/registry/ReleaseRegistry.sol: LogReleaseActivation(VersionPart release)
contracts/registry/ReleaseRegistry.sol: LogReleaseDisabled(VersionPart release)
contracts/registry/ReleaseRegistry.sol: LogReleaseEnabled(VersionPart release)

===============
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenRegistered(ChainId chainId, address token, uint256 decimals, string symbol)
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenGlobalStateSet(ChainId chainId, address token, bool active)
contracts/registry/TokenRegistry.sol: LogTokenRegistryTokenStateSet(ChainId chainId, address token, VersionPart release, bool active)

===============
contracts/shared/IComponent.sol: LogComponentWalletAddressChanged(address oldWallet, address newWallet)
contracts/shared/IComponent.sol: LogComponentWalletTokensTransferred(address from, address to, uint256 amount)
contracts/shared/IComponent.sol: LogComponentTokenHandlerApproved(address tokenHandler, address token, Amount limit, bool isMaxAmount)

===============
contracts/shared/IComponentService.sol: LogComponentServiceComponentLocked(address component, bool locked)
contracts/shared/IComponentService.sol: LogComponentServiceTokenHandlerDeployed(NftId componentNftId, address tokenHandler, address token)
contracts/shared/IComponentService.sol: LogComponentServiceRegistered(NftId instanceNftId, NftId componentNftId, ObjectType componentType, address component, address token, address initialOwner)
contracts/shared/IComponentService.sol: LogComponentServiceWalletAddressChanged(NftId componentNftId, address currentWallet, address newWallet)
contracts/shared/IComponentService.sol: LogComponentServiceWalletTokensTransferred(NftId componentNftId, address currentWallet, address newWallet, uint256 currentBalance)
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
contracts/staking/IStaking.sol: LogStakingStakingRateSet(ChainId chainId, address token, UFixed newStakingRate, UFixed oldStakingRate, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingStakingServiceSet(address stakingService, VersionPart release, address oldStakingService)
contracts/staking/IStaking.sol: LogStakingStakingReaderSet(address stakingReader, address oldStakingReader)
contracts/staking/IStaking.sol: LogStakingTargetHandlerSet(address targetManager, address oldTargetHandler)
contracts/staking/IStaking.sol: LogStakingTokenHandlerApproved(address token, Amount approvalAmount, Amount oldApprovalAmount)
contracts/staking/IStaking.sol: LogStakingTokenAdded(ChainId chainId, address token)
contracts/staking/IStaking.sol: LogStakingTargetTokenAdded(NftId targetNftId, ChainId chainId, address token)
contracts/staking/IStaking.sol: LogStakingTvlIncreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTvlDecreased(NftId targetNftId, address token, Amount amount, Amount newBalance, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingSupportInfoSet(ObjectType objectType, bool isSupported, bool allowNewTargets, bool allowCrossChain, Amount minStakingAmount, Amount maxStakingAmount, Seconds minLockingPeriod, Seconds maxLockingPeriod, UFixed minRewardRate, UFixed maxRewardRate, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetCreated(NftId targetNftId, ObjectType objectType, Seconds lockingPeriod, UFixed rewardRate)
contracts/staking/IStaking.sol: LogStakingLimitsSet(NftId targetNftId, Amount marginAmount, Amount hardLimitAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLimitsUpdated(NftId targetNftId, Amount marginAmount, Amount hardLimitAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLimitUpdated(NftId targetNftId, Amount limitAmount, Amount hardLimitAmount, Amount requiredStakeAmount, Amount actualStakeAmount, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetLockingPeriodSet(NftId targetNftId, Seconds oldLockingPeriod, Seconds lockingPeriod, Blocknumber lastUpdateIn)
contracts/staking/IStaking.sol: LogStakingTargetRewardRateSet(NftId targetNftId, UFixed rewardRate, UFixed oldRewardRate, Blocknumber lastUpdateIn)
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
contracts/staking/IStakingService.sol: LogStakingServiceInstanceTargetRegistered(NftId instanceNftId, uint256 chainId, Seconds initialLockingPeriod, UFixed initialRewardRate)
contracts/staking/IStakingService.sol: LogStakingServiceLockingPeriodSet(NftId targetNftId, Seconds oldLockingDuration, Seconds lockingDuration)
contracts/staking/IStakingService.sol: LogStakingServiceRewardRateSet(NftId targetNftId, UFixed oldRewardRate, UFixed rewardRate)
contracts/staking/IStakingService.sol: LogStakingServiceRewardReservesIncreased(NftId targetNftId, address rewardProvider, Amount dipAmount, Amount newBalance)
contracts/staking/IStakingService.sol: LogStakingServiceRewardReservesDecreased(NftId targetNftId, address targetOwner, Amount dipAmount, Amount newBalance)
contracts/staking/IStakingService.sol: LogStakingServiceStakeObjectCreated(NftId stakeNftId, NftId targetNftId, address stakeOwner)
contracts/staking/IStakingService.sol: LogStakingServiceStakeCreated(NftId stakeNftId, NftId targetNftId, address owner, Amount stakedAmount)
contracts/staking/IStakingService.sol: LogStakingServiceStakeIncreased(NftId stakeNftId, address owner, Amount stakedAmount, Amount stakeBalance)
contracts/staking/IStakingService.sol: LogStakingServiceUnstaked(NftId stakeNftId, address stakeOwner, Amount totalAmount)
contracts/staking/IStakingService.sol: LogStakingServiceStakeRestaked(address stakeOwner, NftId stakeNftId, NftId newStakeNftId, NftId newTargetNftId, Amount newStakeBalance)
contracts/staking/IStakingService.sol: LogStakingServiceRewardsUpdated(NftId stakeNftId)
contracts/staking/IStakingService.sol: LogStakingServiceRewardsClaimed(NftId stakeNftId, address stakeOwner, Amount rewardsClaimedAmount)

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