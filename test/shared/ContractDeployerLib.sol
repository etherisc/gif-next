// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

library ContractDeployerLib {

    event LogContractDeployed(address contractAddress);

    error ErrorCreationCodeHashMismatch(bytes32 expectedHash, bytes32 actualHash);

    /// @dev deploys a new contract using the provided creation code
    function deploy(
        bytes memory creationCode,
        bytes32 expectedCreationCodeHash
    ) 
        public
        returns (address contractAdress)
    {
        // check against expected hash, if provided
        if (expectedCreationCodeHash != bytes32(0)) {
            bytes32 creationCodeHash = getHash(creationCode);
            if (creationCodeHash != expectedCreationCodeHash) {
                revert ErrorCreationCodeHashMismatch(expectedCreationCodeHash, creationCodeHash);
            }
        }

        // solhint-disable no-inline-assembly
        assembly {
            contractAdress := create(0, add(creationCode, 0x20), mload(creationCode))  

            if iszero(extcodesize(contractAdress)) {
                revert(0, 0)
            }
        }
        // solhint enable

        emit LogContractDeployed(contractAdress);
    }

    /// @dev gets the creation code for the new contract
    // for terminology see eg https://www.rareskills.io/post/ethereum-contract-creation-code
    function getCreationCode(
        bytes memory byteCodeWithInitCode, // what you get with type(<Contract>).creationCode
        bytes memory encodedConstructorArguments // what you get with 
    )
        public
        pure
        returns (bytes memory creationCode)
    {
        return abi.encodePacked(byteCodeWithInitCode, encodedConstructorArguments);
    }


    function matchesWithHash(
        bytes memory creationCode,
        bytes32 expectedHash
    )
        public
        pure
        returns (bool isMatching)
    {
        return getHash(creationCode) == expectedHash;
    }


    function getHash(bytes memory creationCode)
        public
        pure
        returns (bytes32 hash)
    {
        return keccak256(creationCode);
    }
}