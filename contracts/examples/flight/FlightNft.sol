// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IPolicy} from "../../instance/module/IPolicy.sol";
import {IRegistry} from "../../registry/IRegistry.sol";

import {Amount} from "../../type/Amount.sol";
import {ChainNft} from "../../registry/ChainNft.sol";
import {FlightProduct} from "./FlightProduct.sol";
import {InstanceReader} from "../../instance/InstanceReader.sol";
import {NftId, NftIdLib} from "../../type/NftId.sol";
import {RiskId} from "../../type/RiskId.sol";


/**
 * @title FlightNft
 * @dev FlightNft provides NFT data for flight delay policies.
 */
// contract FlightNft is IERC721Metadata {
contract FlightNft is
    ERC721, 
    Ownable
{

    error ErrorFlightNftNotMinter();
    error ErrorFlightNftAlreadyMinted(uint256 tokenId);
    error ErrorFlightNftNotAvailable(uint256 tokenId);
    error ErrorFlightNftNotFlightPolicy(uint256 tokenId);

    ChainNft public immutable chainNft;
    FlightProduct public immutable flightProduct;
    InstanceReader public immutable instanceReader;
    IRegistry public registry;

    address public minter;
    string private _baseUri;


    modifier onlyMinter() {
        if(msg.sender != minter) {
            revert ErrorFlightNftNotMinter();
        }
        _;
    }


    constructor(
        address flightProductAddress,
        string memory nftName,
        string memory nftSymbol,
        string memory baseUri
    ) 
        ERC721(nftName, nftSymbol)
        Ownable(msg.sender)
    {
        flightProduct = FlightProduct(flightProductAddress);
        registry = flightProduct.getRegistry();
        chainNft = ChainNft(registry.getChainNftAddress());
        instanceReader = flightProduct.getInstance().getInstanceReader();

        minter = msg.sender;
        _baseUri = baseUri;
    }


    /**
     * Set the base URI to the specified value.
     * Once set, this results in tokenURI() to return <baseUri><tokenId>.
     */
    function setBaseURI(string memory baseUri)
        public 
        onlyOwner()
    {
        _baseUri = baseUri;
    }


    /**
     * Set the minter address.
     */
    function setMinter(address minterAddress)
        public 
        onlyOwner()
    {
        minter = minterAddress;
    }


    /**
     * Mints a metadata NFT for the specified chainNft NFT.
     * Only the minter can mint such NFTs.
     */
    function mint(uint256 tokenId)
        external
        onlyMinter()
    {
        // verify nft does not yet exist
        if (_ownerOf(tokenId) != address(0)) {
            revert ErrorFlightNftAlreadyMinted(tokenId);
        }

        // verify nft on chainNft exists
        // also checks if nft exists (ERC721NonexistentToken)
        address nftOwner = chainNft.ownerOf(tokenId);

        // verify nft is flight delay policy
        if (registry.getParentNftId(NftIdLib.toNftId(tokenId)) != registry.getNftIdForAddress(address(flightProduct))) {
            revert ErrorFlightNftNotFlightPolicy(tokenId);
        }   

        _mint(nftOwner, tokenId);
    }


    /**
     * @dev Return the NFT token URI for the specified token.
     * No check is performed to ensure the token exists.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, toString(tokenId)) : "";
    }


    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal override view returns (string memory) {
        return _baseUri;
    }


    function approve(address to, uint256 tokenId) public override { _revert(); }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override { _revert(); }
    function setApprovalForAll(address operator, bool approved) public override { _revert(); }
    function transferFrom(address from, address to, uint256 tokenId) public override { _revert(); }

    function balanceOf(address owner) public override view returns (uint256 balance) {
        return chainNft.balanceOf(owner);
    }

    function getApproved(uint256 tokenId) public override view returns (address operator) {
        return chainNft.getApproved(tokenId);
    }

    function isApprovedForAll(address owner, address operator) public override view returns (bool) {
        return chainNft.isApprovedForAll(owner, operator);
    }

    function ownerOf(uint256 tokenId) public override view returns (address owner) {
        return chainNft.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
        return chainNft.supportsInterface(interfaceId);
    }


    function getPolicyData(NftId policyNftId)
        public
        view
        returns (
            RiskId riskId,
            string memory flightData,
            string memory departureTimeLocal,
            string memory arrivalTimeLocal,
            Amount premiumAmount, 
            Amount[5] memory payoutAmounts,
            bytes1 status,
            int256 delayMinutes
        )
    {
        IPolicy.PolicyInfo memory info = instanceReader.getPolicyInfo(policyNftId);

        // get financial data
        premiumAmount = info.premiumAmount;

        if (info.applicationData.length > 0) {
            (, payoutAmounts) = abi.decode(info.applicationData, (Amount, Amount[5]));
        }

        // get risk data
        riskId = info.riskId;
        bytes memory data = instanceReader.getRiskInfo(riskId).data;

        if (data.length > 0) {
            FlightProduct.FlightRisk memory flightRisk = flightProduct.decodeFlightRiskData(data);
            flightData = flightRisk.flightData.toString();
            departureTimeLocal = flightRisk.departureTimeLocal;
            arrivalTimeLocal = flightRisk.arrivalTimeLocal;
            status = flightRisk.status;
            delayMinutes = flightRisk.delayMinutes;
        }
    }


    function toString(uint256 value) public pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        uint index = digits - 1;

        temp = value;
        while (temp != 0) {
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;

            if (index > 0) {
                index--;
            }
        }

        return string(buffer);
    }

    function _revert() private pure {
        revert("FlightNft: Use GIF Chain NFT contract to interact with NFTs. See function getChainNft()");
    }
}