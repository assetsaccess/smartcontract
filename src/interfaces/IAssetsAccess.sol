// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAssetsAccess
 * @dev Interface for the AssetsAccess contract, defining core functionalities
 * for managing real estate asset tokenization and trading
 */
interface IAssetsAccess {
    /**
     * @dev Struct representing a real estate property
     */
    struct Property {
        address owner;       // Address of the property owner
        string location;     // Physical location of the property
        uint256 value;       // Total value of the property in USDC
        uint256 fractions;   // Number of fractions the property is divided into
        bool isVerified;     // Whether the property has been verified
        bool isTokenized;    // Whether tokens have been issued for the property
    }

    /**
     * @dev Event emitted when a new property is submitted for tokenization
     */
    event PropertySubmitted(uint256 indexed propertyId, address indexed owner, string location, uint256 value, uint256 fractions);

    /**
     * @dev Event emitted when a property is verified
     */
    event PropertyVerified(uint256 indexed propertyId);

    /**
     * @dev Event emitted when tokens are issued for a property
     */
    event TokensIssued(uint256 indexed propertyId, uint256 amount);

    /**
     * @dev Event emitted when tokens are purchased
     */
    event TokensPurchased(uint256 indexed propertyId, address indexed buyer, uint256 amount, uint256 pricePaid);

    /**
     * @dev Event emitted when the platform fee percentage is updated
     */
    event PlatformFeeUpdated(uint256 newFeePercentage);

    /**
     * @dev Event emitted when the fee collector address is updated
     */
    event FeeCollectorUpdated(address newFeeCollector);

    /**
     * @dev Submits a new property for tokenization
     * @param _location Physical location of the property
     * @param _value Total value of the property in USDC
     * @param _fractions Number of fractions to divide the property into
     */
    function submitProperty(string memory _location, uint256 _value, uint256 _fractions) external;

    /**
     * @dev Verifies a submitted property
     * @param _propertyId Unique identifier of the property to verify
     */
    function verifyProperty(uint256 _propertyId) external;

    /**
     * @dev Issues tokens for a verified property
     * @param _propertyId Unique identifier of the property to tokenize
     */
    function issueTokens(uint256 _propertyId) external;

    /**
     * @dev Allows a user to purchase tokens of a property
     * @param _propertyId Unique identifier of the property to purchase tokens for
     * @param _amount Number of tokens to purchase
     */
    function purchaseTokens(uint256 _propertyId, uint256 _amount) external;

    /**
     * @dev Retrieves all tokenized property listings
     * @return An array of property IDs that have been tokenized
     */
    function getAllListings() external view returns (uint256[] memory);

    /**
     * @dev Retrieves details of a specific property
     * @param _propertyId Unique identifier of the property
     * @return Property struct containing all details of the specified property
     */
    function getPropertyDetails(uint256 _propertyId) external view returns (Property memory);

    /**
     * @dev Updates the platform fee percentage
     * @param _newFeePercentage New fee percentage in basis points (e.g., 250 for 2.5%)
     */
    function updatePlatformFee(uint256 _newFeePercentage) external;

    /**
     * @dev Updates the fee collector address
     * @param _newFeeCollector Address of the new fee collector
     */
    function updateFeeCollector(address _newFeeCollector) external;

    /**
     * @dev Retrieves the latest price from the Chainlink price feed
     * @return The latest price as an int
     */
    function getLatestPrice() external view returns (int);
}