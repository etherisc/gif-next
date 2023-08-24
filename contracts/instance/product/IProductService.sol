// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


import {IOwnable, IRegistryLinked, IRegisterable} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";


interface IProduct {

    struct PoolInfo {
        uint256 nftId;
        address wallet;
        address token;
        uint256 capital;
        uint256 lockedCapital;
    }

}


// TODO or name this IProtectionService to have Product be something more generic (loan, savings account, ...)
interface IProductService is
    IRegistryLinked
{

    function createApplication(
        address applicationOwner,
        uint256 sumInsuredAmount,
        uint256 premiumAmount,
        uint256 lifetime,
        uint256 bundleNftId
    )
        external 
        returns(uint256 nftId);

    // function revoke(unit256 nftId) external;

    function underwrite(uint256 nftId) external;
    // function decline(uint256 nftId) external;
    // function expire(uint256 nftId) external;
    function close(uint256 nftId) external;

    // function collectPremium(uint256 nftId, uint256 premiumAmount) external;

    // function createClaim(uint256 nftId, uint256 claimAmount) external;
    // function confirmClaim(uint256 nftId, uint256 claimId, uint256 claimAmount) external;
    // function declineClaim(uint256 nftId, uint256 claimId) external;
    // function closeClaim(uint256 nftId, uint256 claimId) external;
}


interface IProductModule is
    IOwnable,
    IRegistryLinked,
    IProduct
{
    function getProductService() external view returns(IProductService);
}
