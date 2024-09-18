// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {IRegistryLinked} from "./IRegistryLinked.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {Registry} from "../registry/Registry.sol";
import {RegistryAdmin} from "../registry/RegistryAdmin.sol";

contract RegistryLinkedPure is
    IRegistryLinked
{
    /// @dev initialization for upgradable contracts
    // used in __NftOwnable_init() and __PolicyHolder_init()
    function __RegistryLinkedPure_init(
        address registry
    )
        internal
        virtual
        view
    {
        if (!ContractLib.isRegistry(registry)) {
            revert ErrorRegistryLinkedNotRegistry(address(this), registry);
        }

        if(registry != address(getRegistry())) {
            revert ErrorRegistryLinkedRegistryMismatch(address(this), registry, address(getRegistry()));
        }
    }

    function getRegistry() public pure returns (IRegistry registry)
    {
        bytes32 salt = "0x1234";
        address deployer = address(0x67663Dfd612CfebEB7651A2Da5969258696A77F1);
        address globalRegistry = address(0x1234);

        address accessAdmin = Create2.computeAddress(
            salt, 
            keccak256(abi.encodePacked(
                type(RegistryAdmin).creationCode)), // bytecodeHash
            deployer); 
        
        address registryAddress = Create2.computeAddress(
            salt, 
            keccak256(abi.encodePacked(
                type(Registry).creationCode,
                abi.encode(
                    accessAdmin,
                    globalRegistry))), // bytecodeHash 
            deployer);

        registry = IRegistry(registryAddress);
    }
}