// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, REGISTRY, SERVICE} from "../type/ObjectType.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Timestamp, TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";

import {IService} from "../shared/IService.sol";
import {AccessManagerExtendedWithDisableInitializeable} from "../shared/AccessManagerExtendedWithDisableInitializeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";


contract ReleaseManager is AccessManaged
{
    using ObjectTypeLib for ObjectType;

    event LogReleaseCreation(
        VersionPart version, 
        bytes32 salt, 
        AccessManagerExtendedWithDisableInitializeable releaseAccessManager
    ); 
    event LogReleaseActivation(VersionPart version);


    // prepareRelease
    error ErrorReleaseManagerReleaseEmpty();
    error ErrorReleaseManagerReleaseAlreadyCreated(VersionPart version);
    
    // registerService
    error ErrorReleaseManagerNotService(IService service);
    error ErrorReleaseManagerServiceAddressInvalid(IService given, address expected);

    // activateNextRelease
    error ErrorReleaseManagerReleaseNotCreated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseRegistrationNotFinished(VersionPart releaseVersion, uint awaitingRegistration);
    error ErrorReleaseManagerReleaseAlreadyActivated(VersionPart releaseVersion);

    // disableRelease
    error ErrorReleaseManagerReleaseNotActivated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseAlreadyDisabled(VersionPart releaseVersion);

    // _verifyService
    error ErrorReleaseManagerServiceReleaseAuthorityMismatch(IService service, address serviceAuthority, address releaseAuthority);
    error ErrorReleaseManagerServiceReleaseVersionMismatch(IService service, VersionPart serviceVersion, VersionPart releaseVersion);

    // _verifyServiceInfo
    error ErrorReleaseManagerServiceInfoAddressInvalid(IService service, address expected);
    error ErrorReleaseManagerServiceInfoInterceptorInvalid(IService service, bool isInterceptor);
    error ErrorReleaseManagerServiceInfoTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseManagerServiceInfoOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseManagerServiceSelfRegistration(IService service);
    error ErrorReleaseManagerServiceOwnerRegistered(IService service, address owner);

    // _verifyServiceAuthorizations
    error ErrorReleaseManagerServiceRoleInvalid(address service, RoleId role);

    RegistryAdmin public immutable _admin;
    address public immutable _releaseAccessManagerCodeAddress;
    IRegistry public immutable _registry;

    mapping(VersionPart version => AccessManagerExtendedWithDisableInitializeable accessManager) internal _releaseAccessManager;
    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;
    mapping(address registryService => bool isActive) internal _active;// have access to registry

    VersionPart immutable internal _initial;// first active version    
    VersionPart internal _latest;// latest active version
    VersionPart internal _next;// version to create and activate 

    uint internal _awaitingRegistration; // "services left to register" counter

    constructor(
        RegistryAdmin admin, 
        VersionPart initialVersion)
        AccessManaged(admin.authority())
    {
        _admin = admin;
        _initial = initialVersion;
        _next = VersionPartLib.toVersionPart(initialVersion.toInt() - 1);
        _registry = new Registry();

        AccessManagerExtendedWithDisableInitializeable releaseAccessManager = new AccessManagerExtendedWithDisableInitializeable();
        releaseAccessManager.initialize(address(0x1), VersionLib.toVersionPart(0));
        _releaseAccessManagerCodeAddress = address(releaseAccessManager);
    }

    /// @dev skips previous release if it was not activated
    function createNextRelease() 
        external
        restricted // GIF_ADMIN_ROLE
        returns(VersionPart version)
    {
        _next = VersionPartLib.toVersionPart(_next.toInt() + 1);
        _awaitingRegistration = 0;
    }

    function prepareNextRelease(
        address[] memory addresses,
        string[] memory names, 
        RoleId[][] memory serviceRoles,
        string[][] memory serviceRoleNames,
        RoleId[][] memory functionRoles,
        string[][] memory functionRoleNames,
        bytes4[][][] memory selectors, 
        bytes32 salt
    )
        external
        restricted // GIF_MANAGER_ROLE
        returns(address releaseAccessManagerAddress, VersionPart version, bytes32 releaseSalt)
    {
        if(addresses.length == 0) {
            revert ErrorReleaseManagerReleaseEmpty();
        }

        if(_awaitingRegistration > 0) {
            revert ErrorReleaseManagerReleaseAlreadyCreated(version);
        }

        _verifyReleaseAuthorizations(addresses, serviceRoles, functionRoles, selectors);

        version = getNextVersion();

        _releaseInfo[version].version = version;
        _releaseInfo[version].addresses = addresses;
        _releaseInfo[version].names = names;
        _releaseInfo[version].serviceRoles = serviceRoles;
        _releaseInfo[version].serviceRoleNames = serviceRoleNames;
        _releaseInfo[version].functionRoles = functionRoles;
        _releaseInfo[version].functionRoleNames = functionRoleNames;
        _releaseInfo[version].selectors = selectors;
        _awaitingRegistration = addresses.length;

        version = getNextVersion();
        // ensures unique salt
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));

        releaseAccessManagerAddress = Clones.cloneDeterministic(_releaseAccessManagerCodeAddress, releaseSalt);
        AccessManagerExtendedWithDisableInitializeable releaseAccessManager = AccessManagerExtendedWithDisableInitializeable(releaseAccessManagerAddress);
        releaseAccessManager.initialize(address(this), version);

        _releaseAccessManager[version] = releaseAccessManager;

        emit LogReleaseCreation(version, releaseSalt, releaseAccessManager);
    }

    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        (
            IRegistry.ObjectInfo memory info,
            ObjectType domain,
            VersionPart version
        ) = _verifyService(service);

        if(_awaitingRegistration == 0) {
            // TODO either release is not created or registration is finished
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _awaitingRegistration);
        }

        uint serviceIdx = _awaitingRegistration - 1;
        address serviceAddress = _releaseInfo[version].addresses[serviceIdx];
        // TODO temp, while typescript addresses computation is not implemented 
        /*if(address(service) != serviceAddress) {
            revert ErrorReleaseManagerServiceAddressInvalid(service, serviceAddress);
        }*/

        _setServiceAuthorizations(
            _releaseAccessManager[version],
            // TODO temp, while typescript addresses computation is not implemented
            address(service),//serviceAddress, 
            _releaseInfo[version].names[serviceIdx], 
            _releaseInfo[version].serviceRoles[serviceIdx],
            _releaseInfo[version].serviceRoleNames[serviceIdx],
            _releaseInfo[version].functionRoles[serviceIdx],
            _releaseInfo[version].functionRoleNames[serviceIdx],
            _releaseInfo[version].selectors[serviceIdx]);

        _awaitingRegistration = serviceIdx;
        _releaseInfo[version].domains.push(domain);// checked in registry

        nftId = _registry.registerService(info, version, domain);

        service.linkToRegisteredNftId();
    }

    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        address service = _registry.getServiceAddress(REGISTRY(), version);

        // release exists, registry service is a MUST
        //if(_releaseAccessManager[version] == address(0)) {
        if(service == address(0)) {
            revert ErrorReleaseManagerReleaseNotCreated(version);
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _awaitingRegistration);
        }

        // release is not activated
        if(_releaseInfo[version].activatedAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyActivated(version);
        }

        _latest = version;

        _active[service] = true;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
    }
    
    // TODO rename activatedAt to createdAt
    // consider lastActivatedAt
    function disableRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        // release was activated
        if(_releaseInfo[version].activatedAt.eqz()) {
            revert ErrorReleaseManagerReleaseNotActivated(version);
        }

        // release not disabled already
        if(_releaseInfo[version].disabledAt.gtz()) {
            revert ErrorReleaseManagerReleaseAlreadyDisabled(version);
        }

        // disable release access manager
        _releaseAccessManager[version].disable();
        
        // disable registry service
        address registryServiceAddress = _registry.getServiceAddress(REGISTRY(), version);
        _active[registryServiceAddress] = false;

        _releaseInfo[version].disabledAt = TimestampLib.blockTimestamp();
    }
    // TODO consider reenable delay (few month), after expiration can not enable back
    // after expiration release is not maintained in case of error:
    // 1). we will not emeregency shutdown because of no fixing will be done -> right
    // 2). we can shutdown but it never be enabled afterwards
    function enableRelease(VersionPart version)
        external
        restricted // GIF_ADMIN_ROLE
    {
        // release not disabled already
        if(_releaseInfo[version].disabledAt.eqz()) {
            //revert ErrorReleaseManagerReleaseAlreadyDisabled(version);
        }

        // disable release access manager
        _releaseAccessManager[version].enable();
        
        // disable registry service
        address registryServiceAddress = _registry.getServiceAddress(REGISTRY(), version);
        _active[registryServiceAddress] = true;

        _releaseInfo[version].disabledAt = zeroTimestamp();
    }

    //--- view functions ----------------------------------------------------//

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) external pure returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, salt, deployer);
    }

    function isActiveRegistryService(address service) external view returns(bool) {
        return _active[service];
    }

    function isActiveRelease(VersionPart version) external view returns(bool) {
        return _releaseInfo[version].disabledAt.gtz() ? false : _releaseInfo[version].activatedAt.gtz();
    }


    function getRegistry() external view returns(address) 
    {
        return (address(_registry));
    }

    function getReleaseInfo(VersionPart version) external view returns(IRegistry.ReleaseInfo memory) {
        return _releaseInfo[version];
    }

    function getNextVersion() public view returns(VersionPart) {
        return _next;
    }

    function getLatestVersion() external view returns(VersionPart) {
        return _latest;
    }

    function getInitialVersion() external view returns(VersionPart) {
        return _initial;
    }

    function getReleaseAccessManager(VersionPart version) external view returns(AccessManagerExtendedWithDisableInitializeable) {
        return _releaseAccessManager[version];
    }

    //--- private functions ----------------------------------------------------//

    function _verifyService(IService service)
        internal
        returns(
            IRegistry.ObjectInfo memory serviceInfo,
            ObjectType serviceDomain, 
            VersionPart serviceVersion
        )
    {
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert ErrorReleaseManagerNotService(service);
        }

        address owner = msg.sender;
        address serviceAuthority = service.authority();
        serviceVersion = service.getVersion().toMajorPart();
        serviceDomain = service.getDomain();// checked in registry
        serviceInfo = service.getInitialInfo();

        _verifyServiceInfo(service, serviceInfo, owner);

        VersionPart releaseVersion = getNextVersion(); // never 0
        address releaseAuthority = address(_releaseAccessManager[releaseVersion]); // can be zero if registering service when release is not created

        // IMPORTANT: can not guarantee service access is actually controlled by authority
        if(serviceAuthority != releaseAuthority) {
            revert ErrorReleaseManagerServiceReleaseAuthorityMismatch(
                service,
                serviceAuthority,
                releaseAuthority);
        }

        if(serviceVersion != releaseVersion) {
            revert ErrorReleaseManagerServiceReleaseVersionMismatch(
                service,
                serviceVersion,
                releaseVersion);            
        }
    }

    function _verifyServiceInfo(
        IService service,
        IRegistry.ObjectInfo memory info,
        address expectedOwner // assume always valid, can not be 0
    )
        internal
        view
    {
        if(info.objectAddress != address(service)) {
            revert ErrorReleaseManagerServiceInfoAddressInvalid(service, address(service));
        }

        if(info.isInterceptor != false) { // service is never interceptor
            revert ErrorReleaseManagerServiceInfoInterceptorInvalid(service, info.isInterceptor);
        }

        if(info.objectType != SERVICE()) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorReleaseManagerServiceInfoTypeInvalid(service, SERVICE(), info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseManagerServiceInfoOwnerInvalid(service, expectedOwner, owner); 
        }

        if(owner == address(service)) {
            revert ErrorReleaseManagerServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(owner)) { 
            revert ErrorReleaseManagerServiceOwnerRegistered(service, owner);
        }
    }

    function _verifyReleaseAuthorizations(
        address[] memory serviceAddress,
        RoleId[][] memory serviceRoles,
        RoleId[][] memory functionRoles,
        bytes4[][][] memory selectors
    )
        internal
        view
    {
        for(uint serviceIdx = 0; serviceIdx < serviceAddress.length; serviceIdx++)
        {
            for(uint roleIdx = 0; roleIdx < serviceRoles[serviceIdx].length; roleIdx++)
            {
                RoleId role = serviceRoles[serviceIdx][roleIdx];
                if(role == ADMIN_ROLE()) {
                    revert ErrorReleaseManagerServiceRoleInvalid(serviceAddress[serviceIdx], role);
                }
            }
        }
        // TODO no duplicate service "domain" role per release
        // TODO no duplicate service roles per service
        // TODO no duplicate service function roles per service
        // TODO no duplicate service function selectors per service
    }

    function _setServiceAuthorizations(
        AccessManagerExtendedWithDisableInitializeable accessManager, // release access manager
        address serviceAddress,
        string memory serviceName,
        RoleId[] memory serviceRoles,
        string[] memory serviceRoleNames,
        RoleId[] memory functionRoles,
        string[] memory functionRoleNames,
        bytes4[][] memory selectors
    )
        internal
    {
        accessManager.createTarget(serviceAddress, serviceName);

        for(uint idx = 0; idx < functionRoles.length; idx++)
        {
            uint64 roleInt = functionRoles[idx].toInt();

            if(!accessManager.isRoleExists(roleInt)) {
                accessManager.createRole(roleInt, functionRoleNames[idx]);
            }

            accessManager.setTargetFunctionRole(
                serviceAddress, 
                selectors[idx],
                roleInt);
        }
    
        for(uint idx = 0; idx < serviceRoles.length; idx++)
        {
            uint64 roleInt = serviceRoles[idx].toInt();

            if(!accessManager.isRoleExists(roleInt)) {
                accessManager.createRole(roleInt, serviceRoleNames[idx]);
            }

            accessManager.grantRole(
                serviceRoles[idx].toInt(),
                serviceAddress, 
                0);
        }
    
    }
}