// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {RoleId} from "../type/RoleId.sol";
import {IService} from "../shared/IService.sol";
import {IRegistry} from "./IRegistry.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IComponent} from "../shared/IComponent.sol";

interface IRegistryService is 
     IService
{
     error SelfRegistration();
     error NotRegistryOwner();

     error NotService();
     error NotInstance();
     error NotProduct();
     error NotPool();
     error NotDistribution();

     error UnexpectedRegisterableType(ObjectType expected, ObjectType found);
     error NotRegisterableOwner(address expectedOwner);
     error RegisterableOwnerIsZero();   
     error RegisterableOwnerIsRegistered();
     error InvalidInitialOwner(address initialOwner);
     error InvalidAddress(address registerableAddress);

     struct FunctionConfig
     {
          ObjectType serviceDomain;
          bytes4[] selectors;
     }

     function getFunctionConfigs()
          external
          pure
          returns(
               FunctionConfig[] memory config
          );

     function registerInstance(IRegisterable instance, address owner)
          external returns(IRegistry.ObjectInfo memory info); 

     function registerProduct(IComponent product, address owner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerPool(IComponent pool, address owner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerDistribution(IComponent distribution, address owner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerDistributor(IRegistry.ObjectInfo memory info) external returns(NftId nftId);

     function registerPolicy(IRegistry.ObjectInfo memory info) external returns(NftId nftId);

     function registerBundle(IRegistry.ObjectInfo memory info) external returns(NftId nftId); 
}

