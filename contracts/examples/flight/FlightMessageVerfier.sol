// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


import {Amount} from "../../type/Amount.sol";
import {Str} from "../../type/String.sol";
import {Timestamp} from "../../type/Timestamp.sol";

contract FlightMessageVerifier is 
    Ownable
{
    // EIP-712 Depeg specifics
    string public constant EIP712_DOMAIN_NAME = "EtheriscFlight";
    string public constant EIP712_DOMAIN_VERSION = "1";

    string public constant EIP712_POLICY_TYPE = "Policy(Str carrierFlightNumber,Str departureYearMonthDay,Timestamp departureTime,Timestamp arrivalTime,Amount premiumAmount,uint256[6] memory statistics)";
    bytes32 private constant EIP712_POLICY_TYPE_HASH = keccak256(abi.encodePacked(EIP712_POLICY_TYPE));

    error ErrorFlightMessageVerifierSignerZero();
    error ErrorFlightMessageVerifierContractSignerNotSupported();

    address private _expectedSigner;


    constructor() Ownable(msg.sender) { }


    function setExpectedSigner(address signer) external onlyOwner {
        if (signer == address(0)) { revert ErrorFlightMessageVerifierSignerZero(); }
        if (signer.code.length > 0) { revert ErrorFlightMessageVerifierContractSignerNotSupported(); }
        _expectedSigner = signer;
    }


    function getExpectedSigner() external view returns(address) {
        return _expectedSigner;
    }

    /// @dev creates digest hash based on application parameters
    /// proposal:
    /// use "LX 180 ZRH BKK 20241104" (23 chars, should be enough for all flights)
    /// carriers, airports: https://www.iata.org/en/publications/directories/code-search/
    /// flight numbers: https://en.wikipedia.org/wiki/Flight_number
    /// instead of separate strings, coding/decoding done anyway off-chain
    function getEthSignedMessageHash(
        Str flightData,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premiumAmount,
        uint256[6] memory statistics
    )
        public
        view
        returns(bytes32)
    {
        return MessageHashUtils.toEthSignedMessageHash(
            abi.encode(
                flightData,
                departureTime,
                arrivalTime,
                premiumAmount,
                statistics));
    }


    function verifySignerFromMessageHashAndSignature(
        Str flightData,
        Timestamp departureTime,
        Timestamp arrivalTime,
        Amount premiumAmount,
        uint256[6] memory statistics,
        bytes calldata signature
    )
        public
        view
        returns(
            address actualSigner,
            bool success
        )
    {
        bytes32 messageHash = getEthSignedMessageHash(
            flightData,
            departureTime,
            arrivalTime,
            premiumAmount,
            statistics);

        (
            address recovered, 
            ECDSA.RecoverError err, 
        ) = ECDSA.tryRecover(messageHash, signature);

        actualSigner = recovered;
        success = (err == ECDSA.RecoverError.NoError && actualSigner == _expectedSigner);
    }


    // TODO re-enable or cleanup
    // function checkAndRegisterSignature (
    //     address policyHolder,
    //     address protectedWallet,
    //     uint256 protectedBalance,
    //     uint256 duration,
    //     uint256 bundleId,
    //     bytes32 signatureId,
    //     bytes calldata signature
    // )
    //     external 
    // {
    //     bytes32 signatureHash = keccak256(abi.encode(signature));
    //     require(!_signatureIsUsed[signatureHash], "ERROR:DMH-001:SIGNATURE_USED");

    //     address signer = getSignerFromDigestAndSignature(
    //         protectedWallet,
    //         protectedBalance,
    //         duration,
    //         bundleId,
    //         signatureId,
    //         signature);

    //     require(policyHolder == signer, "ERROR:DMH-002:SIGNATURE_INVALID");

    //     _signatureIsUsed[signatureHash] = true;
    // }
}
