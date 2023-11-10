// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC721, ERC721Enumerable} from "@openzeppelin5/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IChainNft} from "./IChainNft.sol";

contract ChainNft is ERC721Enumerable, IChainNft {
    string public constant NAME = "Dezentralized Insurance Protocol Registry";
    string public constant SYMBOL = "DIPR";

    uint256 public constant PROTOCOL_NFT_ID = 1101;
    uint256 public constant GLOBAL_REGISTRY_ID = 2101;

    // remember token uri
    mapping(uint256 tokenId => string uri) private _uri;

    // remember registry
    address private _registry;

    // only used for _getNextTokenId
    uint256 internal _chainIdInt;
    uint256 internal _chainIdDigits;
    uint256 internal _chainIdMultiplier;
    uint256 internal _idNext;
    uint256 internal _totalMinted;

    modifier onlyRegistry() {
        require(msg.sender == _registry, "ERROR:NFT-001:CALLER_NOT_REGISTRY");
        _;
    }

    constructor(address registry) ERC721(NAME, SYMBOL) {
        require(registry != address(0), "ERROR:NFT-010:REGISTRY_ZERO");

        _registry = registry;

        _chainIdInt = block.chainid;
        _chainIdDigits = _countDigits(_chainIdInt);
        _chainIdMultiplier = 10 ** _chainIdDigits;
        _idNext = 3;
    }

    /**
    * @dev mints the next token to register new objects
    */
    function mint(
        address to,
        string memory uri
    ) external override onlyRegistry returns (uint256 tokenId) {
        tokenId = _getNextTokenId();

        if (bytes(uri).length > 0) {
            _uri[tokenId] = uri;
        }

        _safeMint(to, tokenId);
        _totalMinted++;
    }

    /**
    * @dev mints a token for a specified token id
    * not part of the IRegistry interface only needed for
    * initial registry setup (protocol and global registry objects)
    */
    function mint(address to, uint256 tokenId) external onlyRegistry {
        _totalMinted++;
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external override onlyRegistry {
        _requireOwned(tokenId);
        _burn(tokenId);
        delete _uri[tokenId];
    }

    function setURI(
        uint256 tokenId,
        string memory uri
    ) external override onlyRegistry {
        require(bytes(uri).length > 0, "ERROR:CRG-011:URI_EMPTY");

        _requireOwned(tokenId);
        _uri[tokenId] = uri;
    }

    function exists(uint256 tokenId) external view override returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _uri[tokenId];
    }

    function getRegistryAddress() external view override returns (address) {
        return _registry;
    }

    function totalMinted() external view override returns (uint256) {
        return _totalMinted;
    }

    /**
    * @dev token id calculation based on an index value that is supposed
    * to increase with every minted token
    *
    * requirement: each chain registry produces token ids that
    * are guaranteed to not collide with any token id genereated
    * on a different chain
    *
    * format concat(counter,chainid,2 digits for len-of-chain-id)
    * restriction chainid up to 99 digits
    * decode: from right to left:
    * - 2 right most digits encode length of chainid
    * - move number of digits to left as determined above (-> chainid)
    * - the reminder to the left is the counter
    *
    * special cases
    * 1101 -> decentralized insurance protocol
    * 2102 -> global registry
    * 2xxxxx -> chain registry, where xxxxx = <chain-part> 
    *
    * examples
    * 1101
    * ^^ ^
    * || +- 1-digit chain id
    * |+-- chain id = 1 (mainnet)
    * +-- 1st token id on mainnet
    * (1 * 10 ** 1 + 1) * 100 + 1
    * 42987654321010
    * ^ ^          ^
    * | |          +- 10-digit chain id
    * | +-- chain id = 9876543210 (hypothetical chainid)
    * +-- 42nd token id on this chain
    * (42 * 10 ** 10 + 9876543210) * 100 + 10
    * (index * 10 ** digits + chainid) * 100 + digits (1 < digits < 100)
    */
    function calculateTokenId(uint256 idIndex) public view returns (uint256 id) {
        id =
            (idIndex * _chainIdMultiplier + _chainIdInt) *
            100 +
            _chainIdDigits;
    }

    function _getNextTokenId() private returns (uint256 id) {
        id = calculateTokenId(_idNext);
        _idNext++;
    }

    function _countDigits(uint256 num) private pure returns (uint256 count) {
        count = 0;
        while (num != 0) {
            count++;
            num /= 10;
        }
    }
}
