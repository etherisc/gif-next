// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ITransferInterceptor} from "./ITransferInterceptor.sol";

contract ChainNft is ERC721Enumerable {

    event LogTokenInterceptorAddress(uint256 tokenId, address interceptor);

    // constants
    string public constant NAME = "Dezentralized Insurance Protocol NFT";
    string public constant SYMBOL = "DIPNFT";

    uint256 public constant PROTOCOL_NFT_ID = 1101;
    uint256 public constant GLOBAL_REGISTRY_ID = 2101;

    // custom errors
    error ErrorChainNftCallerNotRegistry(address caller);
    error ErrorChainNftRegistryAddressZero();
    error ErrorChainNftUriEmpty();
    error ErrorChainNftUriAlreadySet();

    // contract state

    // remember interceptors
    mapping(uint256 tokenId => address interceptor) private _interceptor;

    // remember token uri
    mapping(uint256 tokenId => string uri) private _uri;

    // remember registry
    address private _registry;

    // only used for _getNextTokenId
    uint256 internal _chainIdDigits;
    uint256 internal _chainIdMultiplier;
    uint256 internal _idNext;
    uint256 internal _totalMinted;

    modifier onlyRegistry() {
        if (msg.sender != _registry) { revert ErrorChainNftCallerNotRegistry(msg.sender); }
        _;
    }

    constructor(address registry)
        ERC721(NAME, SYMBOL)
    {
        if (registry == address(0)) { revert ErrorChainNftRegistryAddressZero(); }

        // NFT contract is deployed by the registry
        _registry = registry;

        _chainIdDigits = _calculateChainIdDigits(block.chainid);
        _chainIdMultiplier = 10 ** _chainIdDigits;

        // the first object registered through normal registration starts with id 4
        // 1 -> protocol
        // 2 -> registry
        // 3 -> staking
        // >= 4 -> all other objects
        _idNext = 4;
        _totalMinted = 0;
    }

    /**
    * @dev mints a token for a specified token id
    * not part of the IRegistry interface only needed for
    * initial registry setup (protocol and global registry objects)
    */
    function mint(
        address to, 
        uint256 tokenId
    )
        external
        onlyRegistry()
    {
        _safeMintWithInterceptorAddress(to, tokenId, address(0));
    }

    /**
    * @dev mints the next token to register new objects
    * non-zero transferInterceptors are recorded and called during nft token transfers.
    * the contract receiving such a notification may decides to revert or record the transfer
    */
    function mint(
        address to,
        address interceptor,
        string memory uri
    )
        public
        onlyRegistry()
        returns (uint256 tokenId) 
    {
        tokenId = _getNextTokenId();

        if (interceptor != address(0)) {
            _interceptor[tokenId] = interceptor;
        }

        if (bytes(uri).length > 0) {
            _uri[tokenId] = uri;
        }

        _safeMintWithInterceptorAddress(to, tokenId, interceptor);
    }


    /**
     * @dev Amend the open zeppelin transferFrom function by an interceptor call if such an interceptor is defined for the nft token id.
     * This allows distribution, product and pool components to be notified when distributors, policies and bundles are transferred.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override (IERC721, ERC721) {
        // default open zeppelin implementation of transferFrom
        super.transferFrom(from, to, tokenId);

        if (_interceptor[tokenId] != address(0)) {
            address operator = msg.sender;
            ITransferInterceptor(_interceptor[tokenId]).nftTransferFrom(from, to, tokenId, operator);
        }
    }


    function burn(uint256 tokenId) external onlyRegistry {
        _requireOwned(tokenId);
        _burn(tokenId);
        delete _uri[tokenId];
    }

    function setURI(
        uint256 tokenId,
        string memory uri
    ) external onlyRegistry {
        if (bytes(uri).length == 0) { revert ErrorChainNftUriEmpty(); }
        if (bytes(_uri[tokenId]).length > 0) { revert ErrorChainNftUriAlreadySet(); }

        _requireOwned(tokenId);
        _uri[tokenId] = uri;
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // gif generally does not revert for view functions
        // this is an exception to keep the openzeppelin nft semantics
        _requireOwned(tokenId);
        return _uri[tokenId];
    }

    function getInterceptor(uint256 tokenId) external view returns (address) {
        return _interceptor[tokenId];
    }

    function getRegistryAddress() external view returns (address) {
        return _registry;
    }

    function totalMinted() external view returns (uint256) {
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
    function calculateTokenId(uint256 idIndex, uint256 chainId) public view returns (uint256 id) {
        if(chainId == block.chainid) {
            return 100 * (idIndex * _chainIdMultiplier + chainId) + _chainIdDigits;
        } else {
            uint256 chainIdDigits = _calculateChainIdDigits(chainId);
            return 100 * (idIndex * (10 ** chainIdDigits) + chainId) + chainIdDigits;
        }
    }

    function calculateTokenId(uint256 idIndex) public view returns (uint256) {
        return 100 * (idIndex * _chainIdMultiplier + block.chainid) + _chainIdDigits;
    }

    function getNextTokenId() external view returns (uint256) {
        return calculateTokenId(_idNext);
    }

    // ---------------- private functions ----------------- //

    function _getNextTokenId() private returns (uint256 id) {
        id = calculateTokenId(_idNext);
        _idNext++;
    }

    function _calculateChainIdDigits(uint256 chainId) private pure returns (uint256) {
        uint256 num = chainId;
        uint256 digits = 0;
        while (num != 0) {
            digits++;
            num /= 10;
        }
        return digits;
    }

    function _safeMintWithInterceptorAddress(
        address to,
        uint256 tokenId,
        address interceptor
    )
        private
    {        
        _totalMinted++;
        _safeMint(to, tokenId);

        emit LogTokenInterceptorAddress(tokenId, interceptor);
    }
}
