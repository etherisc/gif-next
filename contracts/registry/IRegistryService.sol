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

     // _checkInterface()
     error ErrorRegistryServiceNotContract(address notContract);
     error ErrorRegistryServiceInterfaceNotSupported(address registerable, bytes4 interfaceId);

     error ErrorRegistryServiceRegisterableAddressInvalid(IRegisterable registerable, address found);
     error ErrorRegistryServiceRegisterableParentInvalid(IRegisterable registerable, NftId expected, NftId found);
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

     function registerStake(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data)
          external returns(NftId nftId); 

     function registerInstance(IRegisterable instance, address initialOwner)
          external returns(IRegistry.ObjectInfo memory info); 

     function registerComponent(IRegisterable component, NftId parenNftId, ObjectType componentType, address initialOwner)
          external returns(IRegistry.ObjectInfo memory info);

     function registerDistributor(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) external returns(NftId nftId);

     function registerPolicy(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) external returns(NftId nftId);

     function registerBundle(IRegistry.ObjectInfo memory info, address initialOwner, bytes memory data) external returns(NftId nftId); 

}

