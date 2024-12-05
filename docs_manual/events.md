# Log events

```
===============
contracts/accounting/IAccountingService.sol: LogAccountingServiceBalanceChanged(NftId indexed nftId, Amount indexed amount, Amount indexed feeAmount, bool increase, ObjectType objectType)

===============
contracts/authorization/AccessManagerCloneable.sol: LogAccessManagerLocked(address indexed accessManager, bool indexed locked)

===============
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleCreated(RoleId indexed roleId, RoleId indexed roleAdminId, TargetType indexed targetType, string name, string admin)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleActivatedSet(RoleId indexed roleId, bool indexed active, string admin, Blocknumber lastUpdateIn)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleGranted(address indexed account, RoleId indexed roleId, string roleName, string admin)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminRoleRevoked(address indexed account, RoleId indexed roleId, string roleName, string admin)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminTargetCreated(address indexed target, RoleId indexed roleId, bool indexed managed, string name, string admin)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminTargetLockedSet(address indexed target, bool indexed locked, string admin, Blocknumber lastUpdateIn)
contracts/authorization/IAccessAdmin.sol: LogAccessAdminFunctionGranted(address indexed target, Selector indexed selector, RoleId indexed roleId, string func, string admin, Blocknumber lastUpdateIn)

===============
contracts/distribution/IDistributionService.sol: LogDistributionServiceCommissionWithdrawn(NftId indexed distributorNftId, address indexed recipient, Amount indexed  amount, address tokenAddress)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorTypeCreated(NftId indexed distributionNftId, DistributorType distributorType, string indexed name, UFixed indexed commissionPercentage)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorCreated(NftId indexed distributionNftId, NftId indexed distributorNftId, address indexed distributor, DistributorType distributorType)
contracts/distribution/IDistributionService.sol: LogDistributionServiceDistributorTypeChanged(NftId indexed distributorNftId, DistributorType indexed oldDistributorType, DistributorType indexed newDistributorType)
contracts/distribution/IDistributionService.sol: LogDistributionServiceReferralCreated(NftId indexed distributorNftId, ReferralId indexed referralId, string code, UFixed discountPercentage, uint32 maxReferrals, Timestamp expiryAt)
contracts/distribution/IDistributionService.sol: LogDistributionServiceReferralProcessed(NftId indexed distributorNftId, ReferralId indexed referralId, uint32 usedReferrals)
contracts/distribution/IDistributionService.sol: LogDistributionServiceSaleProcessed(NftId indexed distributionNftId, Amount indexed premium, Amount indexed distributionOwnerFee)
contracts/distribution/IDistributionService.sol: LogDistributionServiceSaleProcessedWithReferral(NftId indexed distributionNftId, NftId indexed distributorNftId, ReferralId indexed referralId, uint32 numPoliciesSold, Amount premium, Amount distributionOwnerFee, Amount commissionAmount)

===============
contracts/instance/BundleSet.sol: LogBundleSetPolicyLinked(NftId indexed bundleNftId, NftId indexed policyNftId)
contracts/instance/BundleSet.sol: LogBundleSetPolicyUnlinked(NftId indexed bundleNftId, NftId indexed policyNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleAdded(NftId indexed poolNftId, NftId indexed bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleUnlocked(NftId indexed poolNftId, NftId indexed bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleLocked(NftId indexed poolNftId, NftId indexed bundleNftId)
contracts/instance/BundleSet.sol: LogBundleSetBundleClosed(NftId indexed poolNftId, NftId indexed bundleNftId)

===============
contracts/instance/IBaseStore.sol: LogBaseStoreMetadataCreated(Key32 indexed key, ObjectType indexed objectType, StateId indexed state)
contracts/instance/IBaseStore.sol: LogBaseStoreMetadataUpdated(Key32 indexed key, StateId indexed oldState, StateId indexed newState)

===============
contracts/instance/IInstance.sol: LogInstanceCustomRoleCreated(RoleId indexed roleId, string indexed roleName, RoleId indexed adminRoleId, uint32 maxMemberCount)
contracts/instance/IInstance.sol: LogInstanceCustomRoleActiveSet(RoleId indexed roleId, bool indexed active, address indexed caller)
contracts/instance/IInstance.sol: LogInstanceCustomRoleGranted(RoleId indexed roleId, address indexed account, address indexed caller)
contracts/instance/IInstance.sol: LogInstanceCustomRoleRevoked(RoleId indexed roleId, address indexed account, address indexed caller)
contracts/instance/IInstance.sol: LogInstanceCustomTargetCreated(address indexed target, RoleId indexed targetRoleId, string indexed name)
contracts/instance/IInstance.sol: LogInstanceTargetLocked(address indexed target, bool indexed locked)
contracts/instance/IInstance.sol: LogInstanceCustomTargetFunctionRoleSet(address indexed target, bytes4[] indexed selectors, RoleId indexed roleId)

===============
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceLocked(NftId indexed instanceNftId, bool indexed locked)
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceCreated(NftId indexed instanceNftId, address indexed instance)
contracts/instance/IInstanceService.sol: LogInstanceServiceMasterInstanceRegistered(NftId indexed masterInstanceNftId, address indexed masterInstance, address indexed masterInstanceAdmin, address masterAccessManager, address masterInstanceReader, address masterInstanceBundleSet, address masterInstanceRiskSet, address masterInstanceStore, address masterProductStore)
contracts/instance/IInstanceService.sol: LogInstanceServiceMasterInstanceReaderUpgraded(NftId indexed instanceNfId, address indexed oldInstanceReader, address indexed newInstanceReader)
contracts/instance/IInstanceService.sol: LogInstanceServiceInstanceReaderUpgraded(NftId indexed instanceNfId, address indexed oldInstanceReader, address indexed newInstanceReader)

===============
contracts/instance/InstanceStore.sol: LogProductStoreComponentInfoCreated(NftId indexed componentNftId, StateId indexed state, address indexed createdby, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreComponentInfoUpdated(NftId indexed componentNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStorePoolInfoCreated(NftId indexed poolNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStorePoolInfoUpdated(NftId indexed poolNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorTypeInfoCreated(DistributorType indexed distributorType, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorTypeInfoUpdated(DistributorType indexed distributorType, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorInfoCreated(NftId indexed distributorNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreDistributorInfoUpdated(NftId indexed distributorNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreReferralInfoCreated(ReferralId indexed referralId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreReferralInfoUpdated(ReferralId indexed referralId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreBundleInfoCreated(NftId indexed bundleNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreBundleInfoUpdated(NftId indexed bundleNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/InstanceStore.sol: LogProductStoreRequestInfoCreated(RequestId indexed requestId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/InstanceStore.sol: LogProductStoreRequestInfoUpdated(RequestId indexed requestId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)

===============
contracts/instance/ProductStore.sol: LogProductStoreProductInfoCreated(NftId indexed productNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreProductInfoUpdated(NftId indexed productNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreFeeInfoCreated(NftId indexed productNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreFeeInfoUpdated(NftId indexed productNftId, address indexed updatedBy, address indexed txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreRiskInfoCreated(RiskId indexed riskId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreRiskInfoUpdated(RiskId indexed riskId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePolicyInfoCreated(NftId indexed policyNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePolicyInfoUpdated(NftId indexed policyNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePremiumInfoCreated(NftId indexed policyNftId, StateId indexed state, address indexed createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePremiumInfoUpdated(NftId indexed policyNftId, StateId indexed oldState, StateId indexed newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStoreClaimInfoCreated(NftId indexed policyNftId, ClaimId indexed claimId, StateId indexed state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStoreClaimInfoUpdated(NftId indexed policyNftId, ClaimId indexed claimId, StateId indexed oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)
contracts/instance/ProductStore.sol: LogProductStorePayoutInfoCreated(NftId indexed policyNftId, PayoutId indexed payoutId, StateId indexed state, address createdBy, address txOrigin)
contracts/instance/ProductStore.sol: LogProductStorePayoutInfoUpdated(NftId indexed policyNftId, PayoutId indexed payoutId, StateId indexed oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn)

===============
contracts/instance/RiskSet.sol: LogRiskSetPolicyLinked(RiskId indexed riskId, NftId indexed policyNftId)
contracts/instance/RiskSet.sol: LogRiskSetPolicyUnlinked(RiskId indexed riskId, NftId indexed policyNftId)
contracts/instance/RiskSet.sol: LogRiskSetRiskAdded(NftId indexed productNftId, RiskId indexed riskId)
contracts/instance/RiskSet.sol: LogRiskSetRiskActivated(NftId indexed poolNftId, RiskId indexed riskId)
contracts/instance/RiskSet.sol: LogRiskSetRiskPaused(NftId indexed poolNftId, RiskId indexed riskId)

===============
contracts/oracle/IOracleService.sol: LogOracleServiceRequestCreated(RequestId indexed requestId, NftId indexed requesterNftId, NftId indexed oracleNftId, Timestamp expiryAt)
contracts/oracle/IOracleService.sol: LogOracleServiceResponseProcessed(RequestId indexed requestId, NftId indexed requesterNftId, NftId indexed oracleNftId)
contracts/oracle/IOracleService.sol: LogOracleServiceDeliveryFailed(RequestId indexed requestId, NftId indexed requesterNftId, string indexed functionSignature)
contracts/oracle/IOracleService.sol: LogOracleServiceResponseResent(RequestId indexed requestId, NftId indexed requesterNftId)
contracts/oracle/IOracleService.sol: LogOracleServiceRequestCancelled(RequestId indexed requestId, NftId indexed requesterNftId)

===============
contracts/pool/IBundleService.sol: LogBundleServiceBundleCreated(NftId indexed bundleNftId, NftId indexed poolNftId, Seconds indexed lifetime, Amount fixedFee, UFixed fractionalFee)
contracts/pool/IBundleService.sol: LogBundleServiceBundleClosed(NftId indexed bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleLocked(NftId indexed bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleUnlocked(NftId indexed bundleNftId)
contracts/pool/IBundleService.sol: LogBundleServiceBundleExtended(NftId indexed bundleNftId, Seconds indexed lifetimeExtension, Timestamp indexed extendedExpiredAt)
contracts/pool/IBundleService.sol: LogBundleServiceBundleFeeUpdated(NftId indexed bundleNftId, Amount indexed fixedFee, UFixed indexed fractionalFee)
contracts/pool/IBundleService.sol: LogBundleServiceCollateralLocked(NftId indexed bundleNftId, NftId indexed policyNftId, Amount indexed collateralAmount)
contracts/pool/IBundleService.sol: LogBundleServiceCollateralReleased(NftId indexed bundleNftId, NftId indexed policyNftId, Amount indexed collateralAmount)
contracts/pool/IBundleService.sol: LogBundleServiceBundleStaked(NftId indexed bundleNftId, Amount indexed amount)
contracts/pool/IBundleService.sol: LogBundleServiceBundleUnstaked(NftId indexed bundleNftId, Amount indexed amount)

===============
contracts/pool/IPoolComponent.sol: LogPoolVerifiedByPool(NftId indexed poolNftId, NftId indexed applicationNftId, Amount indexed collateralizationAmount)

===============
contracts/pool/IPoolService.sol: LogPoolServiceMaxBalanceAmountUpdated(NftId indexed poolNftId, Amount indexed previousMaxCapitalAmount, Amount indexed currentMaxCapitalAmount)
contracts/pool/IPoolService.sol: LogPoolServiceWalletFunded(NftId indexed poolNftId, address indexed poolOwner, Amount indexed amount)
contracts/pool/IPoolService.sol: LogPoolServiceWalletDefunded(NftId indexed poolNftId, address indexed poolOwner, Amount indexed amount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleCreated(NftId indexed instanceNftId, NftId indexed poolNftId, NftId indexed bundleNftId)
contracts/pool/IPoolService.sol: LogPoolServiceBundleClosed(NftId indexed instanceNftId, NftId indexed poolNftId, NftId indexed bundleNftId, Amount balanceAmount, Amount feeAmount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleStaked(NftId indexed instanceNftId, NftId indexed poolNftId, NftId indexed bundleNftId, Amount amount, Amount netAmount)
contracts/pool/IPoolService.sol: LogPoolServiceBundleUnstaked(NftId indexed instanceNftId, NftId indexed poolNftId, NftId indexed bundleNftId, Amount amount, Amount netAmount)
contracts/pool/IPoolService.sol: LogPoolServiceFeesWithdrawn(NftId indexed bundleNftId, address indexed recipient, Amount indexed amount, address tokenAddress)
contracts/pool/IPoolService.sol: LogPoolServiceProcessFundedClaim(NftId indexed policyNftId, ClaimId indexed claimId, Amount indexed availableAmount)
contracts/pool/IPoolService.sol: LogPoolServiceApplicationVerified(NftId indexed poolNftId, NftId indexed bundleNftId, NftId indexed applicationNftId, Amount totalCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceCollateralLocked(NftId indexed poolNftId, NftId indexed bundleNftId, NftId indexed applicationNftId, Amount totalCollateralAmount, Amount lockedCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceCollateralReleased(NftId indexed bundleNftId, NftId indexed policyNftId, Amount indexed releasedCollateralAmount)
contracts/pool/IPoolService.sol: LogPoolServiceSaleProcessed(NftId indexed poolNftId, NftId indexed bundleNftId, Amount indexed bundleNetAmount, Amount bundleFeeAmount, Amount poolFeeAmount)
contracts/pool/IPoolService.sol: LogPoolServicePayoutProcessed(NftId indexed poolNftId, NftId indexed bundleNftId, NftId indexed policyNftId, PayoutId payoutId, Amount netPayoutAmount, Amount processingFeeAmount, address payoutBeneficiary)

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
