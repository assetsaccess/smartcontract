// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

/**
 * @title IAssetsAccessToken
 * @dev Interface for the AssetsAccessToken contract, defining core functionalities
 * for managing ERC-1155 tokens representing fractionalized real estate assets
 */
interface IAssetsAccessToken is IERC1155, IERC1155MetadataURI {

    /**
     * @dev Event emitted when a new token type is created
     */
    event TokenTypeCreated(uint256 indexed tokenId, string propertyLocation, uint256 totalSupply);

    /**
     * @dev Event emitted when a token's URI is updated
     */
    event TokenURIUpdated(uint256 indexed tokenId, string newUri);

    /**
     * @dev Mints new tokens
     * @param account Address to receive the minted tokens
     * @param id Token ID to mint
     * @param amount Amount of tokens to mint
     * @param data Additional data to pass to the receiver
     */
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    /**
     * @dev Mints multiple token types at once
     * @param to Address to receive the minted tokens
     * @param ids Array of token IDs to mint
     * @param amounts Array of amounts to mint for each token ID
     * @param data Additional data to pass to the receiver
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;

    /**
     * @dev Burns a specific amount of tokens
     * @param account Address to burn tokens from
     * @param id Token ID to burn
     * @param value Amount of tokens to burn
     */
    function burn(address account, uint256 id, uint256 value) external;

    /**
     * @dev Burns multiple token types at once
     * @param account Address to burn tokens from
     * @param ids Array of token IDs to burn
     * @param values Array of amounts to burn for each token ID
     */
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;

    /**
     * @dev Creates a new token type representing a property
     * @param propertyLocation Location of the property
     * @param initialSupply Initial supply of tokens for this property
     * @return uint256 The ID of the newly created token type
     */
    function createTokenType(string memory propertyLocation, uint256 initialSupply) external returns (uint256);

    /**
     * @dev Sets the URI for a token type
     * @param tokenId The ID of the token to set the URI for
     * @param newUri The new URI to set
     */
    function setTokenURI(uint256 tokenId, string memory newUri) external;

    /**
     * @dev Pauses all token transfers
     */
    function pause() external;

    /**
     * @dev Unpauses all token transfers
     */
    function unpause() external;

    /**
     * @dev Checks if the contract is paused
     * @return bool True if the contract is paused, false otherwise
     */
    function paused() external view returns (bool);

    /**
     * @dev Gets the total supply of tokens for a specific token ID
     * @param id The token ID to check
     * @return The total supply of tokens for the given ID
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @dev Gets the total number of unique token types
     * @return The total number of token types
     */
    function totalTokenTypes() external view returns (uint256);
}