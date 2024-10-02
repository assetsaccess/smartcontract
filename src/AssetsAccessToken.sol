// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

/**
 * @title AssetsAccessToken
 * @dev Implementation of the ERC1155 token standard for real estate asset fractions
 * Includes additional features like access control, pausability, and supply tracking
 */
contract AssetsAccessToken is ERC1155, AccessControl, Pausable, ERC1155Burnable, ERC1155Supply {
    // Define roles for access control
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Mapping to store token URIs for each token ID
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev Constructor to initialize the contract
     * @param uri_ Base URI for token metadata
     */
    constructor(string memory uri_) ERC1155(uri_) {
        // Grant the contract deployer the default admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Mints new tokens
     * @param account Address to receive the minted tokens
     * @param id Token ID to mint
     * @param amount Amount of tokens to mint
     * @param data Additional data to pass to the receiver
     */
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(account, id, amount, data);
    }

    /**
     * @dev Mints multiple token types at once
     * @param to Address to receive the minted tokens
     * @param ids Array of token IDs to mint
     * @param amounts Array of amounts to mint for each token ID
     * @param data Additional data to pass to the receiver
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Pauses all token transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Sets the URI for a token ID
     * @param tokenId The ID of the token to set the URI for
     * @param newuri The new URI to set
     */
    function setTokenURI(uint256 tokenId, string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _tokenURIs[tokenId] = newuri;
        emit URI(newuri, tokenId);
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The ID of the token to get the URI for
     * @return string The URI for the given token ID
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        
        // If token URI is set, return it
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        
        // If not set, return the base URI
        return super.uri(tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer
     * Adds pausability to token transfers
     */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}