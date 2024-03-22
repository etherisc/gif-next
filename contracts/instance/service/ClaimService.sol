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
import {APPLIED, UNDERWRITTEN, ACTIVE, KEEP_STATE, CLOSED} from "../../types/StateId.sol";
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


    function create(
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
                claimData,
                TimestampLib.zero())); // closedAt
    }


    function confirm(NftId policyNftId, ClaimId claimId, Amount claimAmount)
        external
        virtual
        // solhint-disable-next-line no-empty-blocks
    {

    }


    function decline(NftId policyNftId, ClaimId claimId)
        external
        virtual
        // solhint-disable-next-line no-empty-blocks
    {

    }


    function close(NftId policyNftId, ClaimId claimId)
        external
        virtual
        // solhint-disable-next-line no-empty-blocks
    {

    }


    function createPayout(
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


    function payoutExecuted(
        NftId policyNftId, 
        PayoutId payoutId
    )
        external
        virtual
        // solhint-disable-next-line no-empty-blocks
    {

    }


    // internal functions

    function _getAndVerifyInstanceAndProduct() internal view returns (Product product) {
        IRegistry.ObjectInfo memory productInfo;
        (, productInfo,) = _getAndVerifyComponentInfoAndInstance(PRODUCT());
        product = Product(productInfo.objectAddress);
    }
}
