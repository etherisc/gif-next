// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

import {IProductService} from "../product/IProductService.sol";

// TODO check if there is value to introuce IContract and let IPolicy derive from IContract
interface IPolicy {

    struct Policy {
        uint256 nftId;
        uint256 productNftId; // TODO decide if this info is to be kept in the registry and not here
        uint256 state; // applied, withdrawn, rejected, active, closed

        uint256 sumInsuredAmount;
        uint256 premiumAmount;
        uint256 lifetime; // activatedAt + lifetime >= expiredAt

        uint256 createdAt;
        uint256 activatedAt; // time of underwriting
        uint256 expiredAt; // no new claims
        uint256 closedAt; // no locked capital
        uint256 updatedIn; // block id
    }
}

interface IPolicyModule is
    IOwnable,
    IRegistryLinked,
    IPolicy
{

    function getProductService()
        external
        view
        returns(IProductService);

}
