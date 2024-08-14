// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Test, Vm, console} from "../../lib/forge-std/src/Test.sol";
import {ChainNft} from "../../contracts/registry/ChainNft.sol";

import {MockInterceptor} from "../mock/MockInterceptor.sol";

contract ChainNftTest is Test {

    address public registry = makeAddr("registry");
    address public outsider = makeAddr("outsider");
    address public outsider2 = makeAddr("outsider2");
    MockInterceptor public interceptor;
    ChainNft public chainNft;

    function setUp() public {
        chainNft = new ChainNft(registry);
        interceptor = new MockInterceptor();
    }

    function test_chainNftSetUp() public {
        // solhint-disable no-console
        console.log("chain.id", block.chainid);
        console.log("registry", registry);
        console.log("chainNft", address(chainNft));
        console.log("name", chainNft.name());
        console.log("symbol", chainNft.symbol());

        assertEq(chainNft.getRegistryAddress(), registry, "unexpected registry address");

        assertEq(chainNft.name(), chainNft.NAME(), "unexpected message");
        assertEq(chainNft.symbol(), chainNft.SYMBOL(), "unexpected message");

        assertEq(chainNft.totalMinted(), 0, "minted > 0 after contract deploy");
        assertFalse(chainNft.exists(1), "token id 1 exists");

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                1));
        chainNft.tokenURI(1);

        if (block.chainid == 31337) {
            console.log("checking initial token id");
            assertEq(chainNft.calculateTokenId(1), 13133705, "unexpected next token id for index 0");
            assertEq(chainNft.calculateTokenId(2), 23133705, "unexpected next token id for index 1");
        } else {
            console.log("chainid != 31337, not checking initial token id");
        }
        // solhint-enable
    }

    function test_chainNftMintSimpleHappyCase() public {
        uint256 tokenId = chainNft.calculateTokenId(42);
        assertEq(tokenId, 423133705, "unexpected token id for index 42");

        assertEq(chainNft.totalMinted(), 0, "minted > 0 after contract deploy");
        assertFalse(chainNft.exists(tokenId), "token id exists");
        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        assertEq(chainNft.totalMinted(), 1, "minted != 1 after mint");
        assertTrue(chainNft.exists(tokenId), "token 42 does not exists");
        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token 42");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 0), tokenId, "unexpected token id for outsider");

        assertEq(chainNft.getInterceptor(tokenId), address(0), "token 42 with non-zero interceptor");
        assertEq(chainNft.tokenURI(tokenId), "", "unexpected uri for token 42");
    }

    function test_chainNftMintSimpleNotRegistry() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftCallerNotRegistry.selector,
                outsider));
        vm.prank(outsider);
        chainNft.mint(outsider, tokenId);
    }

    function test_chainNftMintSimpleZeroOwner() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InvalidReceiver.selector,
                address(0)));
        vm.prank(registry);
        chainNft.mint(address(0), tokenId);
    }

    function test_chainNftSimpleSetUriHappyCase() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        assertEq(chainNft.tokenURI(tokenId), "", "non-empty uri for token 42");
        string memory uri = "ipfs://someHash";

        vm.prank(registry);
        chainNft.setURI(tokenId, uri);
        assertEq(chainNft.tokenURI(tokenId), uri, "unexpected uri for token 42");
    }

    function test_chainNftSimpleSetUriNotRegistry() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        assertEq(chainNft.tokenURI(tokenId), "", "non-empty uri for token 42");
        string memory uri = "ipfs://someHash";

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftCallerNotRegistry.selector,
                outsider));
        vm.prank(outsider);
        chainNft.setURI(tokenId, uri);
    }

    function test_chainNftSimpleSetUriEmptyUri() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftUriEmpty.selector));
        vm.prank(registry);
        chainNft.setURI(tokenId, "");
    }

    function test_chainNftSimpleSetUriAlreadySet() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        string memory uri = "ipfs://someHash";
        vm.prank(registry);
        chainNft.setURI(tokenId, uri);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftUriAlreadySet.selector));
        vm.prank(registry);
        chainNft.setURI(tokenId, "ipfs://someOtherHash");
    }


    function test_chainNftMintHappyCase() public {
        string memory uri = "ipfs://someHash";
        uint expectedTokenId = 43133705;

        assertEq(chainNft.totalMinted(), 0, "minted > 0 after contract deploy");
        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");

        vm.expectEmit(address(chainNft));
        emit Transfer(address(0), outsider, expectedTokenId);

        vm.expectEmit(address(chainNft));
        emit LogTokenInterceptorAddress(expectedTokenId, address(0));

        vm.recordLogs();

        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(0), uri);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2, "unexpected number of logs");

        assertEq(tokenId, expectedTokenId, "unexpected token id");
        assertEq(chainNft.totalMinted(), 1, "minted != 1 after mint");
        assertTrue(chainNft.exists(tokenId), "token does not exists");
        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 0), tokenId, "unexpected token id for outsider");

        assertEq(chainNft.getInterceptor(tokenId), address(0), "token with non-zero interceptor");
        assertEq(chainNft.tokenURI(tokenId), uri, "unexpected uri for token");
    }

    function test_chainNftMintTwice() public {
        assertEq(chainNft.totalMinted(), 0, "minted > 0 after contract deploy");
        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");

        vm.prank(registry);
        uint256 tokenId1 = chainNft.mint(outsider, address(0), "");
        assertEq(tokenId1, 43133705, "unexpected token 1 id");

        vm.prank(registry);
        uint256 tokenId2 = chainNft.mint(outsider, address(0), "");
        assertEq(tokenId2, 53133705, "unexpected token 2 id");

        assertEq(chainNft.totalMinted(), 2, "minted != 1 after mint");
        assertTrue(chainNft.exists(tokenId1), "token 1 does not exists");
        assertTrue(chainNft.exists(tokenId2), "token 2 does not exists");
        assertEq(chainNft.balanceOf(outsider), 2, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId1), outsider, "unexpected owner for token 1");
        assertEq(chainNft.ownerOf(tokenId2), outsider, "unexpected owner for token 2");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 0), tokenId1, "unexpected token 1 id for outsider");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 1), tokenId2, "unexpected token 2 id for outsider");
    }

    function test_chainNftSetUriAfterMint() public {
        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(interceptor), "");

        assertEq(tokenId, 43133705, "unexpected token id");
        assertEq(chainNft.totalMinted(), 1, "minted != 1 after mint");
        assertTrue(chainNft.exists(tokenId), "token does not exists");
        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 0), tokenId, "unexpected token id for outsider");

        assertEq(chainNft.getInterceptor(tokenId), address(interceptor), "token with non-zero interceptor");
        assertEq(chainNft.tokenURI(tokenId), "", "unexpected uri for token");

        string memory uri = "ipfs://someHash";

        vm.prank(registry);
        chainNft.setURI(tokenId, uri);
        assertEq(chainNft.tokenURI(tokenId), uri, "unexpected uri for token");
    }

    function test_chainNftSetUriAfterMintWhenAlreadySet() public {
        string memory uri = "ipfs://someHash";

        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(interceptor), uri);

        assertEq(chainNft.tokenURI(tokenId), uri, "unexpected uri for token");

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftUriAlreadySet.selector));
        vm.prank(registry);
        chainNft.setURI(tokenId, "ipfs://someOtherHash");
    }

    function test_chainNftMintNotRegistry() public {
        string memory uri = "ipfs://someHash";

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftCallerNotRegistry.selector,
                outsider));
        vm.prank(outsider);
        chainNft.mint(outsider, address(interceptor), uri);
    }

    // keep identical to ChainNft events
    event LogTokenInterceptorAddress(uint256 tokenId, address interceptor);
    // keep identical to IERC721 events
    event Transfer(address indexed from, address indexed to, uint256 indexed value);    

    function test_chainNftMintWithInterceptorHappyCase() public {

        assertEq(chainNft.totalMinted(), 0, "minted > 0 after contract deploy");
        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");

        string memory uri = "ipfs://someHash";
        uint expectedTokenId = 43133705;

        vm.expectEmit(address(chainNft));
        emit Transfer(address(0), outsider, expectedTokenId);

        vm.expectEmit(address(chainNft));
        emit LogTokenInterceptorAddress(expectedTokenId, address(interceptor));

        vm.recordLogs();

        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(interceptor), uri);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // check exact number of logs
        assertEq(entries.length, 2, "unexpected number of logs");

        assertEq(tokenId, expectedTokenId, "unexpected token id minted");
        assertEq(chainNft.totalMinted(), 1, "minted != 1 after mint");
        assertTrue(chainNft.exists(tokenId), "token does not exists");
        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token");
        assertEq(chainNft.tokenOfOwnerByIndex(outsider, 0), tokenId, "unexpected token id for outsider");

        assertEq(chainNft.getInterceptor(tokenId), address(interceptor), "token with invalid interceptor");
        assertEq(chainNft.tokenURI(tokenId), uri, "unexpected uri for token");
    }

    function test_chainNftTransferWithoutInterceptorHappyCase() public {
        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(0), "");

        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.balanceOf(outsider2), 0, "unexpected nft balance for outsider 2");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token");

        vm.expectEmit(address(chainNft));
        emit Transfer(outsider, outsider2, tokenId);

        vm.recordLogs();

        vm.prank(outsider);
        chainNft.transferFrom(outsider, outsider2, tokenId);

        // check we only have 1 event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1);

        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");
        assertEq(chainNft.balanceOf(outsider2), 1, "unexpected nft balance for outsider 2");
        assertEq(chainNft.ownerOf(tokenId), outsider2, "unexpected owner for token");
    }

    // IMPORTANT needs to exactly match with event defined in MockInterceptor
    event LogNftTransferIntercepted(address from, address to, uint256 tokenId, address operator);

    function test_chainNftTransferWithInterceptorHappyCase() public {
        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(interceptor), "");

        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.balanceOf(outsider2), 0, "unexpected nft balance for outsider 2");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token");

        vm.expectEmit(address(chainNft));
        emit Transfer(outsider, outsider2, tokenId);

        vm.expectEmit(address(interceptor));
        emit LogNftTransferIntercepted(outsider, outsider2, tokenId, outsider);

        vm.recordLogs();

        vm.prank(outsider);
        chainNft.transferFrom(outsider, outsider2, tokenId);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // check exact number of logs
        assertEq(entries.length, 2);

        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider");
        assertEq(chainNft.balanceOf(outsider2), 1, "unexpected nft balance for outsider 2");
        assertEq(chainNft.ownerOf(tokenId), outsider2, "unexpected owner for token");
    }


    function test_chainNftTransferNotOwner() public {
        vm.prank(registry);
        uint256 tokenId = chainNft.mint(outsider, address(0), "");

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721InsufficientApproval.selector,
                outsider2,
                tokenId));
        vm.prank(outsider2);
        chainNft.transferFrom(outsider, outsider2, tokenId);
    }


    function test_chainNftBurnHappyCase() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        assertTrue(chainNft.exists(tokenId), "token 42 does not exists");
        assertEq(chainNft.balanceOf(outsider), 1, "unexpected nft balance for outsider");
        assertEq(chainNft.ownerOf(tokenId), outsider, "unexpected owner for token 42");

        vm.prank(registry);
        chainNft.burn(tokenId);

        assertFalse(chainNft.exists(tokenId), "token 42 does not exists");
        assertEq(chainNft.balanceOf(outsider), 0, "unexpected nft balance for outsider after burn");

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                tokenId));
        chainNft.ownerOf(tokenId);
    }

    function test_chainNftBurnNotRegistry() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.prank(registry);
        chainNft.mint(outsider, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainNft.ErrorChainNftCallerNotRegistry.selector,
                outsider));
        vm.prank(outsider);
        chainNft.burn(tokenId);
    }

    function test_chainNftBurnNonexistentNft() public {
        uint256 tokenId = chainNft.calculateTokenId(42);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                tokenId));
        vm.prank(registry);
        chainNft.burn(tokenId);
    }
}
