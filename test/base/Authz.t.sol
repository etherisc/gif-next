// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {IAccess} from "../../contracts/authorization/IAccess.sol";
import {IAuthorization} from "../../contracts/authorization/IAuthorization.sol";
import {IServiceAuthorization} from "../../contracts/authorization/IServiceAuthorization.sol";

import {InstanceAuthorizationV3} from "../../contracts/instance/InstanceAuthorizationV3.sol";
import {ObjectType} from "../../contracts/type/ObjectType.sol";
import {RoleId} from "../../contracts/type/RoleId.sol";
import {RegistryAuthorization} from "../../contracts/registry/RegistryAuthorization.sol";
import {SimpleDistributionAuthorization} from "../../contracts/examples/unpermissioned/SimpleDistributionAuthorization.sol";
import {BasicOracleAuthorization} from "../../contracts/oracle/BasicOracleAuthorization.sol";
import {SimplePoolAuthorization} from "../../contracts/examples/unpermissioned/SimplePoolAuthorization.sol";
import {SimpleProductAuthorization} from "../../contracts/examples/unpermissioned/SimpleProductAuthorization.sol";
import {ServiceAuthorizationV3} from "../../contracts/registry/ServiceAuthorizationV3.sol";
import {Str} from "../../contracts/type/String.sol";


contract AuthorizationTest is Test {

    string public constant COMMIT_HASH = "1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a";

    RegistryAuthorization public registryAuthz;
    IAuthorization public iRegistryAuthz;

    ServiceAuthorizationV3 public serviceAuthz;
    IServiceAuthorization public iServiceAuthz;

    InstanceAuthorizationV3 public instanceAuthz;
    IAuthorization public iInstanceAuthz;

    SimpleProductAuthorization public prodAuthz;
    IAuthorization public iProdAuthz;

    SimpleDistributionAuthorization public distAuthz;
    IAuthorization public iDistAuthz;

    BasicOracleAuthorization public oracleAuthz;
    IAuthorization public iOracleAuthz;

    SimplePoolAuthorization public poolAuthz;
    IAuthorization public iPoolAuthz;

    function setUp() public {
        // registry authorization
        registryAuthz = new RegistryAuthorization(COMMIT_HASH);
        iRegistryAuthz = IAuthorization(address(registryAuthz));

        // service authorization
        serviceAuthz = new ServiceAuthorizationV3(COMMIT_HASH);
        iServiceAuthz = IServiceAuthorization(address(serviceAuthz));

        // instance authorization
        instanceAuthz = new InstanceAuthorizationV3();
        iInstanceAuthz = IAuthorization(address(instanceAuthz));

        // product authorization
        prodAuthz = new SimpleProductAuthorization("SimpleProduct");
        iProdAuthz = IAuthorization(address(prodAuthz));

        // distribution authorization
        distAuthz = new SimpleDistributionAuthorization("SimpleDistribution");
        iDistAuthz = IAuthorization(address(distAuthz));

        // oracle authorization
        oracleAuthz = new BasicOracleAuthorization("SimpleOracle");
        iOracleAuthz = IAuthorization(address(oracleAuthz));

        // pool authorization
        poolAuthz = new SimplePoolAuthorization("SimplePool");
        iPoolAuthz = IAuthorization(address(poolAuthz));
    }


    function test_authorizationSetupRegistryAuthz() public view { _printAuthz(iRegistryAuthz); _checkAuthz(iRegistryAuthz); }
    function test_authorizationSetupServiceAuthz() public view { _printServiceAuthz(iServiceAuthz); _checkServiceAuthz(iServiceAuthz); }

    function test_authorizationSetupInstanceAuthz() public view { _printAuthz(iInstanceAuthz); _checkAuthz(iInstanceAuthz); }
    function test_authorizationSetupProductAuthz() public view { _printAuthz(iProdAuthz); _checkAuthz(iProdAuthz); }
    function test_authorizationSetupDistributionAuthz() public view { _printAuthz(iDistAuthz); _checkAuthz(iDistAuthz); }
    function test_authorizationSetupOracleAuthz() public view { _printAuthz(iOracleAuthz); _checkAuthz(iOracleAuthz); }
    function test_authorizationSetupPoolAuthz() public view { _printAuthz(iPoolAuthz); _checkAuthz(iPoolAuthz); }


    function _checkServiceAuthz(IServiceAuthorization iAuthz) internal view {
        ObjectType[] memory serviceDomains = iAuthz.getServiceDomains();

        for(uint256 i = 0; i < serviceDomains.length; i++) {
            Str target = iAuthz.getServiceTarget(serviceDomains[i]);
            _checkTargetAuthz(address(iAuthz), target);
        }
    }


    function _checkAuthz(IAuthorization iAuthz) internal view {
        Str[] memory targets = iAuthz.getTargets();

        for(uint256 i = 0; i < targets.length; i++) {
            Str target = targets[i];
            _checkTargetAuthz(address(iAuthz), target);
        }
    }


    function _checkTargetAuthz(address iAuthzAddress, Str target) internal view {
        IAuthorization iAuthz = IAuthorization(iAuthzAddress);
        RoleId [] memory roleIds = iAuthz.getAuthorizedRoles(target);

        for (uint256 j = 0; j < roleIds.length; j++) {
            RoleId roleId = roleIds[j];

            if (roleId.eqz()) { console.log(target.toString(), "role", j); }
            assertTrue(roleId.gtz(), "role id zero");
        }
    }


    function _printAuthz(IAuthorization iAuthz) internal view {
        // solhint-disable
        console.log("---", iAuthz.getMainTargetName() ,"--------------");
        console.log("main target name (via target):", iAuthz.getMainTarget().toString());
        console.log("main target role:", iAuthz.getTargetRole(iAuthz.getMainTarget()).toInt());
        // solhint-enable

        _printServiceDomains(address(iAuthz), false);
        _printRoles(address(iAuthz));
        _printTargets(iAuthz);
        _printFunctions(iAuthz);
    }


    function _printServiceAuthz(IServiceAuthorization iAuthz) internal view {
        // solhint-disable
        console.log("---", iAuthz.getMainTargetName() ,"--------------");
        console.log("main target name (via target):", iAuthz.getMainTarget().toString());
        console.log("main target role:", iAuthz.getTargetRole(iAuthz.getMainTarget()).toInt());
        // solhint-enable

        _printServiceDomains(address(iAuthz), true);
        _printRoles(address(iAuthz));
    }


    function _printRoles(address addreiAuthzAddress) internal view {
        IAuthorization iAuthz = IAuthorization(addreiAuthzAddress);
        RoleId[] memory roles = iAuthz.getRoles();

        // solhint-disable next-line 
        console.log("--- roles", roles.length, "----------");

        for(uint256 i = 0; i < roles.length; i++) {
            RoleId roleId = roles[i];
            string memory roleName = iAuthz.getRoleInfo(roleId).name.toString();

            // solhint-disable next-line 
            console.log("role:", roleId.toInt(), roleName);
        }
    }

    function _printTargets(IAuthorization iAuthz) internal view {
        Str[] memory targets = iAuthz.getTargets();

        // solhint-disable next-line 
        console.log("--- targets", targets.length, "----------");

        for(uint256 i = 0; i < targets.length; i++) {
            Str target = targets[i];
            RoleId roleId = iAuthz.getTargetRole(target);

            // solhint-disable
            if (roleId.gtz()) {
                string memory roleName = iAuthz.getRoleInfo(roleId).name.toString();
                console.log("target:", target.toString(), roleName, roleId.toInt());
            } else {
                // solhint-disable next-line 
                console.log("target:", target.toString(), "<none>");
            }
            // solhint-enable
        }
    }

    function _printFunctions(IAuthorization iAuthz) internal view {
        // solhint-disable next-line 
        console.log("--- functions -----------------------");

        Str[] memory targets = iAuthz.getTargets();
        for(uint256 i = 0; i < targets.length; i++) {
            Str target = targets[i];

            RoleId [] memory roleIds = iAuthz.getAuthorizedRoles(target);
            if (roleIds.length > 0) {
                // solhint-disable next-line 
                console.log("target:", target.toString());

                for(uint256 j = 0; j < roleIds.length; j++) {
                    _printRoleGrantings(iAuthz, target, roleIds[j]);
                }
            }
        }
    }

    function _printServiceDomains(address authz, bool printFunctions) internal view {   
        IAuthorization iAuthz = IAuthorization(authz);
        ObjectType[] memory serviceDomains = iAuthz.getServiceDomains();

        // solhint-disable next-line 
        console.log("--- service domains", serviceDomains.length, "----------");

        for(uint256 i = 0; i < serviceDomains.length; i++) {
            ObjectType serviceDomain = iAuthz.getServiceDomain(i);
            string memory targetName = iAuthz.getServiceTarget(serviceDomain).toString();
            RoleId targetRole = iAuthz.getServiceRole(serviceDomain);
            string memory roleName = iAuthz.getRoleInfo(targetRole).name.toString();

            // solhint-disable
            console.log("domain:", serviceDomain.toInt(), serviceDomain.toName());
            if (printFunctions) {
                console.log("  target:", targetName, iAuthz.getServiceAddress(serviceDomain));
                console.log("  role:", targetRole.toInt(), roleName);
            }
            // solhint-enable
        }

        if (printFunctions) {
            // solhint-disable next-line 
            console.log("--- authorized functions --------------");
            for(uint256 i = 0; i < serviceDomains.length; i++) {
                ObjectType serviceDomain = iAuthz.getServiceDomain(i);
                Str target = iAuthz.getServiceTarget(serviceDomain);
                RoleId[] memory roleIds = iAuthz.getAuthorizedRoles(target);

                // solhint-disable next-line 
                console.log(target.toString(), "domain", serviceDomain.toInt());

                for(uint256 j = 0; j < roleIds.length; j++) {
                    _printRoleGrantings(iAuthz, target, roleIds[j]);
                }
            }
        }
    }

    function _printRoleGrantings(IAuthorization iAuthz, Str target, RoleId roleId) internal view {
        string memory roleName = iAuthz.getRoleInfo(roleId).name.toString();

        // solhint-disable next-line 
        console.log(" ", roleName, roleId.toInt());

        IAccess.FunctionInfo[] memory functions = iAuthz.getAuthorizedFunctions(target, roleId);
        for(uint256 k = 0; k < functions.length; k++) {
            string memory functionName = string(abi.encodePacked(
                "    - ", functions[k].name.toString(), "()"));

            // solhint-disable next-line
            console.log(functionName);
        }
    }
}