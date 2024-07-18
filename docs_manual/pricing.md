# PricingService sequences 

## calculatePremium

```mermaid
sequenceDiagram
    actor C as Caller
    participant PS as PricingService
    participant P as Product
    participant DS as DistributionService
    participant IR as InstanceReader
    
    C ->> PS: calculatePremium(productNftId, sumInsured, referral, [...])
    PS ->> P: calculateNetPremium(sumInsured)
    P ->> PS: netPremium
    PS ->> PS: _getFixedFeeAmounts()
    PS ->> IR: getProductSetupInfo()<br/> getPoolSetupInfo() <br/> getBundleInfo() <br/> getDistributionSetupInfo()
    PS ->> PS: _calculateVariableFeeAmounts
    PS ->> PS: _calculateDistributionOwnerFeeAmount
    PS ->> DS: calculateFeeAmount(distributionNftId, referral, netPremium, (intermediary)premium)
    DS ->> DS: calculate distribution fee and full premium
    DS ->> DS: referralIsValid()
    DS ->> IR: getReferralInfo()<br/> getDistributorInfo<br/> getDistributorTypeInfo()
    opt if referral is valid
        DS ->> DS: calculate discount, comission based on referral
    end
    DS ->> DS: calculate distribution owner fee  and final premium
    DS ->> PS: premium (final)
    PS ->> C: premium
```
