// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {console, Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // Import ERC20 Permit interface
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol"; // Import ERC20 Permit interface


contract USDCPermitTest is Test {

    address public usdcAddress;  // USDC contract address
    address public user;       // Address that will sign the permit
    uint256 public userPrivateKey;  // User's private key for signing
    uint256 public fork;       // Fork of Base mainnet

    bool public setupSucessful;

    function setUp() public {
        // Fork the Base network
        string memory infuraProjectId = "";
        setupSucessful = false;
        
        try vm.envString("WEB3_INFURA_PROJECT_ID") returns (string memory projectId) {
            infuraProjectId = projectId;

            fork = vm.createFork(string(abi.encodePacked("https://base-mainnet.infura.io/v3/", infuraProjectId)));        
            vm.selectFork(fork);
            
            // USDC contract address on Base
            usdcAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

            // Set up the user and their private key
            user = vm.addr(1);  // Address 1
            userPrivateKey = 1;  // Example private key

            // no exception so far -> setup was successful
            setupSucessful = true;
        } catch { }

    }


    // run this test using the two command below
    // export WEB3_INFURA_PROJECT_ID=<infura project id> 
    // forge test --mt test_flightUsdcPermitHappyCase --fork-url https://base-mainnet.infura.io/v3/$WEB3_INFURA_PROJECT_ID -vv
    function test_flightUsdcPermitHappyCase() public {

        if (!setupSucessful) {
            console.log("Setup failed. Exiting test.");
            return;
        }

        console.log("chain id:", block.chainid);
        console.log("USDC contract address: ", usdcAddress);
        console.log("USDC symbol name: ", IERC20Metadata(usdcAddress).symbol(), IERC20Metadata(usdcAddress).name());

        // GIVEN
        // Fetch the user's nonce from the USDC contract
        uint256 nonce = IERC20Permit(usdcAddress).nonces(user);

        // Set the `deadline` for the permit signature (use block.timestamp for now)
        uint256 deadline = block.timestamp + 1 days;

        // Permit parameters
        address spender = address(this); // Approve this contract
        uint256 value = 1000e6; // 1000 USDC (USDC has 6 decimals)

        // WHEN
        // Create the signature using EIP-712
        bytes32 digest = _getPermitDigest(user, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        assertEq(IERC20Metadata(usdcAddress).allowance(user, spender), 0);

        // Call the permit function on USDC
        IERC20Permit(usdcAddress).permit(user, spender, value, deadline, v, r, s);

        // THEN
        assertEq(IERC20Metadata(usdcAddress).allowance(user, spender), value);
    }


    function _getPermitDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        // EIP-712 domain separator
        // this works as well
        // bytes32 domainSeparator = keccak256(
        //     abi.encode(
        //         keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        //         keccak256(bytes("USD Coin")),        // Name
        //         keccak256(bytes("2")),               // Version
        //         block.chainid,                        // Chain ID for Base
        //         usdcAddress                         // USDC contract address
        //     )
        // );

        // going directly for the DOMAIN_SEPARATOR() getter seems more robust
        bytes32 domainSeparator = IERC20Permit(usdcAddress).DOMAIN_SEPARATOR();

        // EIP-712 permit struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        // Full EIP-712 message digest
        return keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
    }
}