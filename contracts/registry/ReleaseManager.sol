// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import {NftId} from "../type/NftId.sol";
import {RoleId, ADMIN_ROLE, PUBLIC_ROLE} from "../type/RoleId.sol";
import {ObjectType, ObjectTypeLib, zeroObjectType, REGISTRY, SERVICE} from "../type/ObjectType.sol";
import {Version, VersionLib, VersionPart, VersionPartLib} from "../type/Version.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";

import {IService} from "../shared/IService.sol";
import {AccessManagerUpgradeableInitializeable} from "../shared/AccessManagerUpgradeableInitializeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {Registry} from "./Registry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {RegistryAccessManager} from "./RegistryAccessManager.sol";

// TODO finish refactoring
contract ReleaseManager is AccessManaged
{
    using ObjectTypeLib for ObjectType;

    event LogReleaseCreation(VersionPart version, bytes32 salt, AccessManagerUpgradeableInitializeable accessManager); 
    event LogReleaseActivation(VersionPart version);

    // createNextRelease
    error ErrorReleaseManagerServiceAuthorityInvalid(address service, address expected, address found);

    // registerService
    error ErrorReleaseManagerNotService(IService service);


    // activateNextRelease
    error ErrorReleaseManagerReleaseNotCreated(VersionPart releaseVersion);
    error ErrorReleaseManagerReleaseRegistrationNotFinished(VersionPart releaseVersion, uint awaitingRegistration);

    // verifyAndStoreConfig
    error ErrorReleaseManagerConfigMissing();
    error ErrorReleaseManagerConfigAddressInvalid(uint serviceIdx, address serviceAddress);
    error ErrorReleaseManagerConfigRoleInvalid(uint serviceIdx, RoleId roleId);
    error ErrorReleaseManagerConfigFunctionRoleInvalid(uint serviceIdx, uint roleIdx, RoleId roleId);
    // TODO questinable, reverts by default
    error ErrorReleaseManagerConfigSelectorsRolesMismatch(uint serviceIdx, uint selectorsCount, uint rolesCount);

    // _getAndverifyServiceInfo
    error ErrorReleaseManagerServiceReleaseAuthorityMismatch(IService service, address serviceAuthority, address releaseAuthority);
    error ErrorReleaseManagerServiceReleaseVersionMismatch(IService service, VersionPart serviceVersion, VersionPart releaseVersion);
    error ErrorReleaseManagerServiceDomainZero(IService service);

    // _getAndVerifyContractInfo
    error ErrorReleaseManagerServiceAddressInvalid(IService service, address expected);
    error ErrorReleaseManagerServiceTypeInvalid(IService service, ObjectType expected, ObjectType found);
    error ErrorReleaseManagerServiceOwnerInvalid(IService service, address expected, address found);
    error ErrorReleaseManagerServiceSelfRegistration(IService service);
    error ErrorReleaseManagerServiceOwnerRegistered(IService service, address owner);

    struct ConfigStruct {
        address serviceAddress;
        RoleId serviceRole;
        // TODO do not store domain here -> read from service at registration
        // TODO role always reflects domain -> use role instead?
        ObjectType serviceDomain;
        bytes4[][] selectors;
        RoleId[] roles;
    }

    RegistryAccessManager public immutable _accessManager;
    IRegistry public immutable _registry;

    mapping(VersionPart version => AccessManagerUpgradeableInitializeable accessManager) internal _releaseAccessManager;
    mapping(VersionPart version => ConfigStruct[] config) internal _releaseConfig;
    mapping(VersionPart majorVersion => IRegistry.ReleaseInfo info) internal _releaseInfo;

    VersionPart immutable internal _initial;// first active version    
    VersionPart internal _latest;// latest active version
    VersionPart internal _next;// version to create and activate 

    uint internal _awaitingRegistration; // "services left to register" counter

    mapping(address registryService => bool isActive) internal _active;// have access to registry

    constructor(
        RegistryAccessManager accessManager, 
        VersionPart initialVersion)
        AccessManaged(accessManager.authority())
    {
        _accessManager = accessManager;
        _initial = initialVersion;
        _next = VersionPartLib.toVersionPart(initialVersion.toInt() - 1);
        _registry = new Registry();
    }

    /// @dev skips previous release if it was not activated
    function createNextRelease(ConfigStruct[] memory config, bytes32 salt)
        external
        restricted // GIF_ADMIN_ROLE
        returns(address releaseAccessManagerAddress, VersionPart version, bytes32 releaseSalt)
    {
        version = _getNextVersion();//+1
        releaseSalt = keccak256(
            bytes.concat(
                bytes32(version.toInt()),
                salt));
        releaseAccessManagerAddress = Clones.cloneDeterministic(_accessManager.authority(), releaseSalt);
        AccessManagerUpgradeableInitializeable releaseAccessManager = AccessManagerUpgradeableInitializeable(releaseAccessManagerAddress);
        releaseAccessManager.initialize(address(this));

        _releaseAccessManager[version] = releaseAccessManager;
        // TODO store only addresses, read selectors and roles from service at registration???
        _awaitingRegistration = _verifyAndStoreReleaseConfig(config);

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
        ) = _getAndVerifyServiceInfo(service);

        uint serviceIdx = _awaitingRegistration - 1;// reversed registration order of services specified in ReleaseConfig
        ConfigStruct memory config = _releaseConfig[version][serviceIdx];
        AccessManagerUpgradeableInitializeable releaseAccessManager = _releaseAccessManager[version];

        if(config.serviceAddress != address(service)) {
            revert ErrorReleaseManagerServiceAddressInvalid(service, config.serviceAddress);
        }

        _setConfig(releaseAccessManager, config);

        _awaitingRegistration = serviceIdx;
        _releaseInfo[version].domains.push(domain);
        _releaseInfo[version].addresses.push(address(service));

        nftId = _registry.registerService(info, version, domain);

        service.linkToRegisteredNftId();
    }

    function activateNextRelease() 
        external 
        restricted // GIF_ADMIN_ROLE
    {
        VersionPart version = _next;
        address service = _registry.getServiceAddress(REGISTRY(), version);

        // release was created, registry service is a MUST
        //if(_releaseAccessManager[version] == address(0)) {
        if(service == address(0)) {
            revert ErrorReleaseManagerReleaseNotCreated(version);
        }

        // release fully deployed
        if(_awaitingRegistration > 0) {
            revert ErrorReleaseManagerReleaseRegistrationNotFinished(version, _awaitingRegistration);
        }

        //setTargetClosed(service, false);

        _latest = version;

        _active[service] = true;
        _releaseInfo[version].activatedAt = TimestampLib.blockTimestamp();

        emit LogReleaseActivation(version);
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

    function isValidRelease(VersionPart version) external view returns(bool) {
        return _releaseInfo[version].activatedAt.gtz();
    }

    function getRegistry() external view returns(address) {
        return (address(_registry));
    }

    function getReleaseConfig (VersionPart version) external view returns(ConfigStruct[] memory) {
        return _releaseConfig[version];
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

    function getReleaseAccessManager(VersionPart version) external view returns(AccessManagerUpgradeableInitializeable) {
        return _releaseAccessManager[version];
    }

    //--- private functions ----------------------------------------------------//

    function _setConfig(IAccessManager accessManager, ConfigStruct memory config)
        internal
    {
        for(uint idx = 0; idx < config.roles.length; idx++)
        {
            accessManager.setTargetFunctionRole(
                config.serviceAddress, 
                config.selectors[idx], 
                config.roles[idx].toInt());
        }

        accessManager.grantRole(config.serviceRole.toInt(), config.serviceAddress, 0);
    }

    function _getAndVerifyServiceInfo(IService service)
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
        serviceDomain = service.getDomain();
        serviceInfo = _getAndVerifyContractInfo(service, SERVICE(), owner);// owner protection inside

        VersionPart releaseVersion = getNextVersion(); // never 0
        address releaseAuthority = address(_releaseAccessManager[releaseVersion]); // never 0

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

        if(serviceDomain.eqz()) {
            revert ErrorReleaseManagerServiceDomainZero(service);
        }
    }

    function _getAndVerifyContractInfo(
        IService service,
        ObjectType expectedType,
        address expectedOwner // assume always valid, can not be 0
    )
        internal
        // view
        returns(
            IRegistry.ObjectInfo memory info
        )
    {
        info = service.getInitialInfo();
        info.objectAddress = address(service);
        info.isInterceptor = false; // service is never interceptor, at least now

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorReleaseManagerServiceTypeInvalid(service, expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorReleaseManagerServiceOwnerInvalid(service, expectedOwner, owner); 
        }

        if(owner == address(service)) {
            revert ErrorReleaseManagerServiceSelfRegistration(service);
        }
        
        if(_registry.isRegistered(owner)) { 
            revert ErrorReleaseManagerServiceOwnerRegistered(service, owner);
        }
    }

    /// @dev in the worst case scenario it will be impossible to activate release with broken/invalid config
    // the only important checks are for serviceRole, service function roles and config length
    function _verifyAndStoreReleaseConfig(ConfigStruct[] memory config) 
        internal
        returns(uint configLength)
    {
        VersionPart version = getNextVersion();

        // config not empty
        if(config.length == 0) {
            revert ErrorReleaseManagerConfigMissing();
        }

        for(uint serviceIdx = 0; serviceIdx < config.length; serviceIdx++)
        {
            ConfigStruct memory cfg = config[serviceIdx];

            // have no duplicate service addresses accross all releases
            // -> can not register already registered address

            // have no duplicate service addresses in given config
            // -> can not register already registered address

            // have no duplicate service domain in given config
            // -> can not register already registered domain

            // service address is not zero
            if(cfg.serviceAddress == address(0)) {
                revert ErrorReleaseManagerConfigAddressInvalid(
                    serviceIdx, 
                    address(0));
            }
            // service role is not ADMIN_ROLE
            // TODO have no duplicate service role in given config
            if(cfg.serviceRole == ADMIN_ROLE() || cfg.serviceRole == PUBLIC_ROLE()) {
                revert ErrorReleaseManagerConfigRoleInvalid(
                    serviceIdx,
                    cfg.serviceRole);
            }

            // loop will throw error anyway
            if(cfg.selectors.length != cfg.roles.length) {
                revert ErrorReleaseManagerConfigSelectorsRolesMismatch(
                    serviceIdx,
                    cfg.selectors.length, 
                    cfg.roles.length);
            }

            // non of service functions are set to prohibited roles
            // TODO have no duplicate function roles in given service config
            // TODO have no duplicate selectors in given service config
            // TODO have no 0 selectors in given service config
            for(uint roleIdx = 0; roleIdx < cfg.roles.length; roleIdx++) {
                RoleId role = cfg.roles[roleIdx];
                if(role == PUBLIC_ROLE() || role == ADMIN_ROLE()) {
                    revert ErrorReleaseManagerConfigFunctionRoleInvalid(
                        serviceIdx,
                        roleIdx,
                        role);
                }
            }

            _releaseConfig[version].push(cfg);
        }

        return _releaseConfig[version].length;
    }


    function _getNextVersion() internal returns(VersionPart nextVersion) {
        nextVersion = VersionPartLib.toVersionPart(_next.toInt() + 1);
        _next = nextVersion;
    }

/*
    function _verifyService(
        IService service,
        VersionPart expectedVersion,
        ObjectType expectedDomain
    )
        internal
        view
        returns(ObjectType)
    {
        Version version = service.getVersion();
        VersionPart majorVersion = version.toMajorPart();
        if(majorVersion != expectedVersion) {
            revert UnexpectedServiceVersion(expectedVersion, majorVersion);
        }

        if(service.getDomain() != expectedDomain) {
            revert UnexpectedServiceDomain(expectedDomain, service.getDomain());
        }

        return expectedDomain;
    }
*/
}
