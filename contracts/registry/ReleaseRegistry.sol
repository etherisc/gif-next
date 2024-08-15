// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, ObjectTypeLib, POOL, RELEASE, REGISTRY, SERVICE, STAKING} from "../type/ObjectType.sol";
import {TimestampLib, zeroTimestamp} from "../type/Timestamp.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId, SCHEDULED, DEPLOYING, DEPLOYED, SKIPPED, ACTIVE, PAUSED} from "../type/StateId.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";

import {IService} from "../shared/IService.sol";

import {IAccessAdmin} from "../authorization/IAccessAdmin.sol";
import {AccessManagerCloneable} from "../authorization/AccessManagerCloneable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IRegistryLinked} from "../shared/IRegistryLinked.sol";
import {IServiceAuthorization} from "../authorization/IServiceAuthorization.sol";
import {RegistryAdmin} from "./RegistryAdmin.sol";
import {Registry} from "./Registry.sol";
import {ReleaseLifecycle} from "./ReleaseLifecycle.sol";
import {ReleaseAdmin} from "./ReleaseAdmin.sol";


contract ReleaseRegistry is 
    AccessManaged,
    ReleaseLifecycle, 
    IRegistryLinked
{
    uint256 public constant INITIAL_GIF_VERSION = 3;// first active version  

    event LogReleaseCreation(IAccessAdmin admin, VersionPart version, bytes32 salt); 
    event LogReleaseActivation(VersionPart version);
    event LogReleaseDisabled(VersionPart version);
    event LogReleaseEnabled(VersionPart version);

    // constructor
    error ErrorReleaseRegistryNotRegistry(Registry registry);

    // _verifyServiceAuthorization
    error ErrorReleaseRegistryNotServiceAuth(address notAuth);
    error ErrorReleaseRegistryServiceAuthVersionMismatch(IServiceAuthorization auth, VersionPart expected, VersionPart actual);
    error ErrorReleaseRegistryServiceAuthDomainsZero(IServiceAuthorization auth, VersionPart version);

    // registerService
    error ErrorReleaseRegistryServiceAddressMismatch(address expected, address actual);

    // activateNextRelease
    error ErrorReleaseRegistryRegistryServiceMissing(VersionPart releaseVersion);

    // _verifyService
    error ErrorReleaseRegistryNotService(address notService);
    error ErrorReleaseRegistryServiceAuthorityMismatch(IService service, address serviceAuthority, address releaseAuthority);
    error ErrorReleaseRegistryServiceVersionMismatch(IService service, VersionPart serviceVersion, VersionPart releaseVersion);
    error ErrorReleaseRegistryServiceDomainMismatch(IService service, ObjectType expectedDomain, ObjectType actualDomain);

    // _verifyServiceInfo
    error ErrorReleaseRegistryServiceInfoAddressInvalid(IService service, address expected);
    error ErrorReleaseRegistryServiceInfoInterceptorInvalid(IService service, bool isInterceptor);
    error ErrorReleaseRegistryServiceInfoTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseRegistryServiceInfoOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseRegistryServiceSelfRegistration(IService service);
    error ErrorReleaseRegistryServiceOwnerRegistered(IService service, address owner);

    RegistryAdmin public immutable _admin;
    Registry public immutable _registry;

    mapping(VersionPart version => IRegistry.ReleaseInfo info) internal _releaseInfo;
    VersionPart [] internal _release; // array of all created releases    
    ReleaseAdmin _masterReleaseAdmin;

    VersionPart internal _latest; // latest active version
    VersionPart internal _next; // version to create and activate 

    // counters per release
    uint256 internal _registeredServices = 0;
    uint256 internal _servicesToRegister = 0;

    constructor(Registry registry)
        AccessManaged(msg.sender)
    {
        if (!ContractLib.isRegistry(address(registry))) {
            revert ErrorReleaseRegistryNotRegistry(registry);
        }

        setAuthority(registry.getAuthority());

        _registry = registry;
        _admin = RegistryAdmin(_registry.getRegistryAdminAddress());

        _masterReleaseAdmin = new ReleaseAdmin();

        _next = VersionPartLib.toVersionPart(INITIAL_GIF_VERSION - 1);
    }

    /// @dev sets previous release into SKIPPED state if it was created but not activated
    /// sets next release into state SCHEDULED
    function createNextRelease()
        external
        restricted() // GIF_ADMIN_ROLE
        returns(VersionPart)
    {
        VersionPart version = _next;

        if(isValidTransition(RELEASE(), _releaseInfo[version].state, SKIPPED())) {
            _releaseInfo[version].state = SKIPPED();
        }

        version = VersionPartLib.toVersionPart(version.toInt() + 1);
        _release.push(version);

        _next = version;
        _releaseInfo[version].version = version;
        _releaseInfo[version].state = getInitialState(RELEASE());
        _servicesToRegister = 0;
        _registeredServices = 0;

        return _next;
    }

    function prepareNextRelease(
        IServiceAuthorization serviceAuthorization,
        bytes32 salt
    )
        external
        restricted() // GIF_MANAGER_ROLE
        returns(
            IAccessAdmin releaseAdmin, 
            VersionPart releaseVersion, 
            bytes32 releaseSalt
        )
    {
        releaseVersion = _next;

        // release can transition into DEPLOYING state
        checkTransition(_releaseInfo[releaseVersion].state, RELEASE(), SCHEDULED(), DEPLOYING());

        // verify authorizations
        uint256 serviceDomainsCount = _verifyServiceAuthorization(serviceAuthorization, releaseVersion, salt);

        // create and initialize release admin
        releaseAdmin = _createReleaseAdmin();
        releaseSalt = salt;
        // ensures unique salt
        // TODO CreateX have clones capability also
        // what would releaseSalt look like if used with CreateX in pemissioned mode?
        /*releaseSalt = keccak256(
            bytes.concat(
                bytes32(releaseVersion.toInt()),
                salt));*/

        _servicesToRegister = serviceDomainsCount;
        _releaseInfo[releaseVersion].state = DEPLOYING();
        _releaseInfo[releaseVersion].salt = releaseSalt;
        // TODO allow for the same serviceAuthorization address to be used for multiple releases?
        _releaseInfo[releaseVersion].auth = serviceAuthorization;
        _releaseInfo[releaseVersion].admin = releaseAdmin;

        emit LogReleaseCreation(releaseAdmin, releaseVersion, releaseSalt);
    }

    function registerService(IService service) 
        external
        restricted // GIF_MANAGER_ROLE
        returns(NftId nftId)
    {
        VersionPart releaseVersion = _next;

        // release can transition to DEPLOYED state
        checkTransition(_releaseInfo[releaseVersion].state, RELEASE(), DEPLOYING(), DEPLOYED());

        address releaseAuthority = _releaseInfo[releaseVersion].admin.authority();
        IServiceAuthorization releaseAuth = _releaseInfo[releaseVersion].auth;
        ObjectType expectedDomain = releaseAuth.getServiceDomain(_registeredServices);

        // service can work with release registry and release version
        (
            IRegistry.ObjectInfo memory info,
            ObjectType serviceDomain,
            VersionPart serviceVersion
            //,string memory serviceName
        ) = _verifyService(
            service, 
            releaseAuthority, 
            releaseVersion, 
            expectedDomain
        );

        //_releaseInfo[releaseVersion].addresses.push(address(service)); // TODO get this info from auth contract?
        //_releaseInfo[releaseVersion].domains.push(serviceDomain);
        //_releaseInfo[releaseVersion].names.push(serviceName); // TODO if needed read in _verifyService()

        _registeredServices++; // TODO use releaseInfo.someArray.length instead of _registeredServices

        // release fully deployed
        if(_servicesToRegister == _registeredServices) {
            _releaseInfo[releaseVersion].state = DEPLOYED();
        }

        // TODO: service address matches defined in release auth (precalculated one)
        // revert ErrorReleaseRegistryServiceAddressMismatch()

        // setup service authorization
        ReleaseAdmin releaseAdmin = ReleaseAdmin(address(_releaseInfo[releaseVersion].admin));
        releaseAdmin.setReleaseLocked(false);
        releaseAdmin.authorizeService(
            releaseAuth, 
            service,
            serviceDomain,
            releaseVersion);
        releaseAdmin.setReleaseLocked(true); 

        // register service with registry
        nftId = _registry.registerService(info, serviceVersion, serviceDomain);
        service.linkToRegisteredNftId();
    }
    // TODO return activated version
    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;

        // release can transition to ACTIVE state
        checkTransition(_releaseInfo[version].state, RELEASE(), DEPLOYED(), ACTIVE());

        _latest = version;
        _releaseInfo[version].state = ACTIVE();
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        // grant special roles for registry/staking/pool services
        // this will enable access to core contracts functions

        // registry service MUST be registered for each release
        address service = _registry.getServiceAddress(REGISTRY(), version);
        if(service == address(0)) {
            revert ErrorReleaseRegistryRegistryServiceMissing(version);
        }

        _admin.grantServiceRoleForAllVersions(IService(service), REGISTRY());

        service = _registry.getServiceAddress(STAKING(), version);
        if(service != address(0)) {
            _admin.grantServiceRoleForAllVersions(IService(service), STAKING());
        }

        service = _registry.getServiceAddress(POOL(), version);
        if(service != address(0)) {
            _admin.grantServiceRoleForAllVersions(IService(service), POOL());
        }

        _setReleaseLocked(version, false);

        emit LogReleaseActivation(version);
    }

    /// @dev stop/resume operations with restricted functions
    function setActive(VersionPart version, bool active) 
        public
        restricted
    {
        StateId state = _releaseInfo[version].state;

        if(active) {
            checkTransition(state, RELEASE(), PAUSED(), ACTIVE());
            _releaseInfo[version].state = ACTIVE();
            _releaseInfo[version].disabledAt = zeroTimestamp();
            emit LogReleaseEnabled(version);
        } else {
            checkTransition(state, RELEASE(), ACTIVE(), PAUSED());
            _releaseInfo[version].state = PAUSED();
            _releaseInfo[version].disabledAt = TimestampLib.blockTimestamp();
            emit LogReleaseDisabled(version);
        }

        _setReleaseLocked(version, !active);
    }

    //--- view functions ----------------------------------------------------//

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) external pure returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, salt, deployer);
    }

    function isActiveRelease(VersionPart version) public view returns(bool) {
        return _releaseInfo[version].state == ACTIVE();
    }

    function getReleaseInfo(VersionPart version) external view returns(IRegistry.ReleaseInfo memory) {
        return _releaseInfo[version];
    }

    /// @dev Returns the number of created releases.
    /// Releases might be in another state than ACTIVE.
    function releases() external view returns (uint) {
        return _release.length;
    }

    /// @dev Returns the n-th release version.
    /// Valid values for idx [0 .. releases() - 1]
    function getVersion(uint256 idx) external view returns (VersionPart version) {
        // return _releases;
        return _release[idx];
    }

    function getNextVersion() public view returns(VersionPart) {
        return _next;
    }

    /// @dev Returns the latest activated relase version.
    /// There is no guarantee that the release is not currently paused.
    function getLatestVersion() external view returns(VersionPart) {
        return _latest;
    }

    function getState(VersionPart version) external view returns (StateId stateId) {
        return _releaseInfo[version].state;
    }

    function getRemainingServicesToRegister() external view returns (uint256 services) {
        return _servicesToRegister - _registeredServices;
    }

    function getServiceAuthorization(VersionPart version)
        external
        view
        returns (IServiceAuthorization serviceAuthorization)
    {
        return _releaseInfo[version].auth;
    }

    function getRegistryAdmin() external view returns (address) {
        return address(_admin);
    }

    //--- IRegistryLinked ------------------------------------------------------//

    function getRegistry() external view returns (IRegistry) {
        return _registry;
    }

    //--- private functions ----------------------------------------------------//

    function _setReleaseLocked(VersionPart version, bool locked)
        private
    {
        ReleaseAdmin releaseAdmin = ReleaseAdmin(address(_releaseInfo[version].admin));
        releaseAdmin.setReleaseLocked(locked);
    }

    function _createReleaseAdmin()
        private
        returns (ReleaseAdmin clonedAdmin)
    {
        AccessManagerCloneable releaseAccessManager = AccessManagerCloneable(
            Clones.clone(
                _masterReleaseAdmin.authority()
            )
        );
        clonedAdmin = ReleaseAdmin(
            Clones.clone(
                address(_masterReleaseAdmin)
            )
        );
        clonedAdmin.initialize(releaseAccessManager);
        clonedAdmin.completeSetup(address(_registry), address(this), _next);
        clonedAdmin.setReleaseLocked(true);
    }

    function _verifyServiceAuthorization(
        IServiceAuthorization serviceAuthorization,
        VersionPart releaseVersion,
        bytes32 salt
    )
        private
        view
        returns (uint256 serviceDomainsCount)
    {
        // authorization contract supports IServiceAuthorization interface
        if(!serviceAuthorization.supportsInterface(type(IServiceAuthorization).interfaceId)) {
                revert ErrorReleaseRegistryNotServiceAuth(address(serviceAuthorization));
        }

        // authorizaions contract version matches with release version
        VersionPart authVersion = serviceAuthorization.getRelease();
        if (releaseVersion != authVersion) {
            revert ErrorReleaseRegistryServiceAuthVersionMismatch(serviceAuthorization, releaseVersion, authVersion);
        }

        // sanity check to ensure service domain list is not empty
        serviceDomainsCount = serviceAuthorization.getServiceDomains().length;
        if (serviceDomainsCount == 0) {
            revert ErrorReleaseRegistryServiceAuthDomainsZero(serviceAuthorization, releaseVersion);
        }
    }

    // TODO get service names 
    function _verifyService(
        IService service, 
        address expectedAuthority, 
        VersionPart expectedVersion,
        ObjectType expectedDomain
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory serviceInfo,
            ObjectType serviceDomain, 
            VersionPart serviceVersion
        )
    {
        if(!service.supportsInterface(type(IService).interfaceId)) {
            revert ErrorReleaseRegistryNotService(address(service));
        }

        address owner = msg.sender;
        address serviceAuthority = service.authority();
        serviceVersion = service.getVersion().toMajorPart();
        serviceDomain = service.getDomain();// checked in registry
        serviceInfo = service.getInitialInfo();

        _verifyServiceInfo(service, serviceInfo, owner);

        if(serviceAuthority != expectedAuthority) {
            revert ErrorReleaseRegistryServiceAuthorityMismatch(
                service,
                serviceAuthority,
                expectedAuthority);
        }

        if(serviceVersion != expectedVersion) {
            revert ErrorReleaseRegistryServiceVersionMismatch(
                service,
                serviceVersion,
                expectedVersion);            
        }

        if(serviceDomain != expectedDomain) {
            revert ErrorReleaseRegistryServiceDomainMismatch(
                service,
                expectedDomain,
                serviceDomain);
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
            revert ErrorReleaseRegistryServiceInfoAddressInvalid(service, info.objectAddress);
        }

        if(info.isInterceptor != false) { // service is never interceptor
            revert ErrorReleaseRegistryServiceInfoInterceptorInvalid(service, info.isInterceptor);
        }

        if(info.objectType != SERVICE()) {
            revert ErrorReleaseRegistryServiceInfoTypeInvalid(service, SERVICE(), info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseRegistryServiceInfoOwnerInvalid(service, expectedOwner, owner); 
        }

        if(owner == address(service)) {
            revert ErrorReleaseRegistryServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(owner)) { 
            revert ErrorReleaseRegistryServiceOwnerRegistered(service, owner);
        }
    }
}

