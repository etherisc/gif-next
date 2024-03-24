// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "./IApplicationService.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {Product} from "../../components/Product.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IInstance} from "../IInstance.sol";
import {IPolicy} from "../module/IPolicy.sol";
import {IRisk} from "../module/IRisk.sol";
import {IBundle} from "../module/IBundle.sol";
import {IProductService} from "./IProductService.sol";
import {ITreasury} from "../module/ITreasury.sol";
import {ISetup} from "../module/ISetup.sol";

import {TokenHandler} from "../../shared/TokenHandler.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {Amount, AmountLib} from "../../types/Amount.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../../types/Timestamp.sol";
import {UFixed, UFixedLib} from "../../types/UFixed.sol";
import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL, APPLICATION, POLICY, CLAIM, BUNDLE} from "../../types/ObjectType.sol";
import {SUBMITTED, ACTIVE, KEEP_STATE, DECLINED, CONFIRMED, CLOSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, FeeLib} from "../../types/Fee.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {ClaimId, ClaimIdLib} from "../../types/ClaimId.sol";
import {PayoutId, PayoutIdLib} from "../../types/PayoutId.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {ComponentService} from "../base/ComponentService.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IBundleService} from "./IBundleService.sol";
import {IClaimService} from "./IClaimService.sol";
import {IPoolService} from "./IPoolService.sol";
import {IService} from "../../shared/IService.sol";
import {Service} from "../../shared/Service.sol";


contract ClaimService is 
    ComponentService, 
    IClaimService
{

    IPoolService internal _poolService;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        // TODO check this, might no longer be the way, refactor if necessary
        address registryAddress;
        address initialOwner;
        (registryAddress, initialOwner) = abi.decode(data, (address, address));

        initializeService(registryAddress, address(0), owner);

        _poolService = IPoolService(getRegistry().getServiceAddress(POOL(), getVersion().toMajorPart()));

        registerInterface(type(IClaimService).interfaceId);
    }


    function getDomain() public pure override returns(ObjectType) {
        return CLAIM();
    }


    function submit(
        IInstance instance,
        NftId policyNftId, 
        ClaimId claimId, 
        Amount claimAmount,
        bytes memory claimData
    )
        external
        virtual
        // TODO add restricted and grant to policy service
    {
        instance.createClaim(
            policyNftId, 
            claimId, 
            IPolicy.ClaimInfo(
                claimAmount,
                AmountLib.zero(), // paidAmount
                0, // payoutsCount
                0, // openPayoutsCount
                claimData,
                TimestampLib.zero())); // closedAt
    }


    function confirm(
        IInstance instance,
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId, 
        Amount confirmedAmount
    )
        external
        virtual
    {
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.claimAmount = confirmedAmount;
        instance.updateClaim(policyNftId, claimId, claimInfo, CONFIRMED());
    }

    function decline(
        IInstance instance,
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
    {
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, SUBMITTED());
        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.updateClaim(policyNftId, claimId, claimInfo, DECLINED());
    }


    function close(
        IInstance instance,
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId
    )
        external
        virtual
    {
        IPolicy.ClaimInfo memory claimInfo = _verifyClaim(instanceReader, policyNftId, claimId, CONFIRMED());

        // check claim has no open payouts
        if(claimInfo.openPayoutsCount > 0) {
            revert ErrorClaimServiceClaimWithOpenPayouts(
                policyNftId, 
                claimId, 
                claimInfo.openPayoutsCount);
        }

        // check claim paid amount matches with claim amount
        if(claimInfo.paidAmount.toInt() < claimInfo.claimAmount.toInt()) {
            revert ErrorClaimServiceClaimWithMissingPayouts(
                policyNftId, 
                claimId, 
                claimInfo.claimAmount,
                claimInfo.paidAmount);
        }

        claimInfo.closedAt = TimestampLib.blockTimestamp();
        instance.updateClaim(policyNftId, claimId, claimInfo, CLOSED());
    }


    function createPayout(
        IInstance instance,
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId,
        Amount payoutAmount,
        bytes calldata payoutData
    )
        external
        virtual
        returns(PayoutId payoutId)
        // solhint-disable-next-line no-empty-blocks
    {

    }


    function processPayout(
        IInstance instance,
        InstanceReader instanceReader,
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
        returns (
            Amount amount,
            bool payoutIsClosingClaim
        )
        // solhint-disable-next-line no-empty-blocks
    {

    }


    // internal functions

    function _verifyClaim(
        InstanceReader instanceReader,
        NftId policyNftId, 
        ClaimId claimId, 
        StateId expectedState
    )
        internal
        view
        returns (
            IPolicy.ClaimInfo memory claimInfo
        )
    {
        // check claim is created state
        StateId claimState = instanceReader.getClaimState(policyNftId, claimId);
        if(claimState != expectedState) {
            revert ErrorClaimServiceClaimNotInExpectedState(
                policyNftId, claimId, expectedState, claimState);
        }

        // get claim info
        claimInfo = instanceReader.getClaimInfo(policyNftId, claimId);
    }

    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }
}
