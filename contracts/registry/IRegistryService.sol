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
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";


interface IRegistryService is 
     IService
{
     error ErrorRegistryServiceNotRegistryOwner();

     error ErrorRegistryServiceNotService(address notService);
     error ErrorRegistryServiceNotInstance(address notInstance);
     error ErrorRegistryServiceNotProduct(address notProduct);
     error ErrorRegistryServiceNotComponent(address notComponent);
     error ErrorRegistryServiceNotProductLinkedComponent(address notProductLinkedComponent);

     error ErrorRegistryServiceRegisterableAddressInvalid(IRegisterable registerable, address found);
     error ErrorRegistryServiceRegisterableTypeInvalid(IRegisterable registerable, ObjectType expected, ObjectType found);
     error ErrorRegistryServiceRegisterableOwnerInvalid(IRegisterable registerable, address expected, address found);
     error ErrorRegistryServiceRegisterableOwnerZero(IRegisterable registerable);   
     error ErrorRegistryServiceRegisterableOwnerRegistered(IRegisterable registerable, address owner);
     error ErrorRegistryServiceRegisterableSelfRegistration(IRegisterable registerable);

     error ErrorRegistryServiceObjectAddressNotZero(ObjectType objectType);
     error ErrorRegistryServiceObjectTypeInvalid(ObjectType expected, ObjectType found);
     error ErrorRegistryServiceObjectOwnerRegistered(ObjectType objectType, address owner);
     error ErrorRegistryServiceObjectOwnerZero(ObjectType objectType);

     error ErrorRegistryServiceInvalidInitialOwner(address initialOwner);
     error ErrorRegistryServiceInvalidAddress(address registerableAddress);

     function registerStake(IRegistry.ObjectInfo memory info)
          external returns(NftId nftId); 

     function registerInstance(IRegisterable instance, address owner)
          external returns(IRegistry.ObjectInfo memory info); 

     function registerProduct(IComponent product, address owner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerProductLinkedComponent(IComponent component, ObjectType objectType, address owner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerDistributor(IRegistry.ObjectInfo memory info) external returns(NftId nftId);

     function registerPolicy(IRegistry.ObjectInfo memory info) external returns(NftId nftId);

     function registerBundle(IRegistry.ObjectInfo memory info) external returns(NftId nftId); 

}

