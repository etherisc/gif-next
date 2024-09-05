// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount, AmountLib} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IAccountingService} from "./IAccountingService.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ACCOUNTING, BUNDLE, DISTRIBUTION, DISTRIBUTOR, POOL, PRODUCT} from "../type/ObjectType.sol";
import {Service} from "../shared/Service.sol";


contract AccountingService is
    Service,
    IAccountingService
{
    bool private constant INCREASE = true;
    bool private constant DECREASE = false;

    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);
        _registerInterface(type(IAccountingService).interfaceId);
    }

    function decreaseComponentFees(
        InstanceStore instanceStore, 
        NftId componentNftId, 
        Amount feeAmount
    ) 
        external
        virtual
        restricted()
    {
        _changeTargetBalance(DECREASE, instanceStore, componentNftId, AmountLib.zero(), feeAmount);    
    }


    function increaseProductFees(
        InstanceStore instanceStore,
        NftId productNftId, 
        Amount feeAmount
    ) 
        external 
        virtual 
        restricted()
    {
        _checkNftType(productNftId, PRODUCT());
        _changeTargetBalance(INCREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }

    function increaseProductFeesForPool(
        InstanceStore instanceStore,
        NftId productNftId, 
        Amount feeAmount
    ) 
        external 
        virtual 
        restricted()
    {
        _checkNftType(productNftId, PRODUCT());
        _changeTargetBalance(INCREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }


    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount)
        external 
        virtual 
        restricted()
    {
        _checkNftType(productNftId, PRODUCT());
        _changeTargetBalance(DECREASE, instanceStore, productNftId, AmountLib.zero(), feeAmount);
    }

    function increaseDistributionBalance(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount amount,
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(distributionNftId, DISTRIBUTION());
        _changeTargetBalance(INCREASE, instanceStore, distributionNftId, amount, feeAmount);
    }


    function decreaseDistributionBalance(
        InstanceStore instanceStore, 
        NftId distributionNftId, 
        Amount amount,
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(distributionNftId, DISTRIBUTION());
        _changeTargetBalance(DECREASE, instanceStore, distributionNftId, amount, feeAmount);
    }

    function increaseDistributorBalance(
        InstanceStore instanceStore, 
        NftId distributorNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(distributorNftId, DISTRIBUTOR());
        _changeTargetBalance(INCREASE, instanceStore, distributorNftId, amount, feeAmount);
    }

    function decreaseDistributorBalance(
        InstanceStore instanceStore, 
        NftId distributorNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(distributorNftId, DISTRIBUTOR());
        _changeTargetBalance(DECREASE, instanceStore, distributorNftId, amount, feeAmount);
    }

    function increasePoolBalance(
        InstanceStore instanceStore, 
        NftId poolNftId, 
        Amount amount, 
        Amount feeAmount
    )
        public 
        virtual 
        restricted()
    {
        _checkNftType(poolNftId, POOL());
        _changeTargetBalance(INCREASE, instanceStore, poolNftId, amount, feeAmount);
    }

    function decreasePoolBalance(
        InstanceStore instanceStore, 
        NftId poolNftId, 
        Amount amount, 
        Amount feeAmount
    )
        public 
        virtual
        restricted()
    {
        _checkNftType(poolNftId, POOL());
        _changeTargetBalance(DECREASE, instanceStore, poolNftId, amount, feeAmount);
    }

    function increaseBundleBalance(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());
        _changeTargetBalance(INCREASE, instanceStore, bundleNftId, amount, feeAmount);
    }

    function decreaseBundleBalance(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());
        _changeTargetBalance(DECREASE, instanceStore, bundleNftId, amount, feeAmount);
    }

    function increaseBundleBalanceForPool(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());
        _changeTargetBalance(INCREASE, instanceStore, bundleNftId, amount, feeAmount);
    }

    function decreaseBundleBalanceForPool(
        InstanceStore instanceStore, 
        NftId bundleNftId, 
        Amount amount, 
        Amount feeAmount
    )
        external
        virtual
        restricted()
    {
        _checkNftType(bundleNftId, BUNDLE());
        _changeTargetBalance(DECREASE, instanceStore, bundleNftId, amount, feeAmount);
    }


    //-------- internal functions ------------------------------------------//

    function _changeTargetBalance(
        bool increase,
        InstanceStore instanceStore, 
        NftId targetNftId, 
        Amount amount, 
        Amount feeAmount
    )
        internal
        virtual
    {
        Amount totalAmount = amount + feeAmount;

        if(increase) {
            if(totalAmount.gtz()) { instanceStore.increaseBalance(targetNftId, totalAmount); }
            if(feeAmount.gtz()) { instanceStore.increaseFees(targetNftId, feeAmount); }
        } else {
            if(totalAmount.gtz()) { instanceStore.decreaseBalance(targetNftId, totalAmount); }
            if(feeAmount.gtz()) { instanceStore.decreaseFees(targetNftId, feeAmount); }
        }
    }


    function _logUpdateFee(NftId productNftId, string memory name, Fee memory feeBefore, Fee memory feeAfter)
        internal
        virtual
    {
        emit LogComponentServiceUpdateFee(
            productNftId, 
            name,
            feeBefore.fractionalFee,
            feeBefore.fixedFee,
            feeAfter.fractionalFee,
            feeAfter.fixedFee
        );
    }

    function _getDomain() internal pure virtual override returns(ObjectType) {
        return ACCOUNTING();
    }


}