// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessAdmin} from "../authorization/AccessAdmin.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IModuleAuthorization} from "./IModuleAuthorization.sol";
import {IServiceAuthorization} from "./IServiceAuthorization.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, INSTANCE} from "../type/ObjectType.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {ReleaseManager} from "../registry/ReleaseManager.sol";
import {RoleId} from "../type/RoleId.sol";
import {VersionPart} from "../type/Version.sol";

contract InstanceAdmin is
     AccessAdmin,
     RegistryLinked
{

     // initialize
     error ErrorInstanceAdminNotInstance(address instance);
     error ErrorInstanceAdminNotRegisteredInstance(address instance);
     error ErrorInstanceAdminServiceVersionMismatch();

     IInstance private _instance;
     IModuleAuthorization private _instanceAuthz;
     IServiceAuthorization private _serviceAuthz;

     function initialize(
          address registry,
          address instance,
          IModuleAuthorization instanceAuthz
     )
          external
          initializer() 
     {
          initializeRegistryLinked(registry);
          _initializeInstance(instance);
          _initializeAuthorization(instanceAuthz);
     }


    //--- view functions ----------------------------------------------------//

     function getInstance() external view returns(IInstance instance) {
          return _instance;
     }

     function getInstanceAuthorization() external view returns(IModuleAuthorization serviceAuthz) {
          return _instanceAuthz;
     }

     function getServiceAuthorization() external view returns(IServiceAuthorization serviceAuthz) {
          return _serviceAuthz;
     }

    //--- private functions -------------------------------------------------//

     function _initializeInstance(address instance)
          private
          onlyInitializing()
     {
          IRegistry registry = getRegistry();
          IRegistry.ObjectInfo memory info = registry.getObjectInfo(instance);

          if (info.objectType != INSTANCE()) {
               revert ErrorInstanceAdminNotInstance(instance);
          }

          if (info.nftId.eqz()) {
               revert ErrorInstanceAdminNotRegisteredInstance(instance);
          }

          _instance = IInstance(instance);
     }


     function _initializeAuthorization(
          IModuleAuthorization instanceAuthz
     )
          private
          onlyInitializing()
     {
          // check instance version matches with authz relase
          VersionPart release = instanceAuthz.getRelease();
          if(release != _instance.getMajorVersion()) {
               revert ErrorInstanceAdminServiceVersionMismatch();
          }

          _instanceAuthz = instanceAuthz;
          _serviceAuthz = _getServiceAuthorization(release);
     }


     function _getServiceAuthorization(VersionPart release)
          private
          view
          returns (IServiceAuthorization serviceAuthz)
     {
          ReleaseManager releaseManager = ReleaseManager(
               getRegistry().getReleaseManagerAddress());

          return releaseManager.getServiceAuthorization(release);
     }

}

