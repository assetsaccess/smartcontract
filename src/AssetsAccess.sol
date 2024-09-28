// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import necessary OpenZeppelin contracts for token standards, access control, and security
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title AssetsAccess
 * @dev A smart contract for tokenizing and trading real estate assets
 * 
 * This contract allows property owners to tokenize their real estate assets,
 * have them verified, and then trade fractions of these properties. It uses
 * the ERC1155 token standard for representing property fractions, implements
 * role-based access control, and includes security measures against reentrancy attacks.
 */
contract AssetsAccess is ERC1155, AccessControl, ReentrancyGuard {
    // Define roles for access control
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    /**
     * @dev Struct to represent a property
     * @param owner Address of the property owner
     * @param location String description of the property location
     * @param value Total value of the property in USDC
     * @param fractions Number of fractions the property is divided into
     * @param isVerified Boolean indicating if the property has been verified
     * @param isTokenized Boolean indicating if tokens have been issued for the property
     */
    struct Property {
        address owner;
        string location;
        uint256 value;
        uint256 fractions;
        bool isVerified;
        bool isTokenized;
    }
    
    // Mapping to store all properties, indexed by a unique property ID
    mapping(uint256 => Property) public properties;
    // Counter to keep track of the total number of properties and generate unique IDs
    uint256 public propertyCount;
    
    // Interface for the USDC token used for payments
    IERC20 public usdcToken;
    // Interface for Chainlink price feed (can be used for dynamic pricing in future iterations)
    AggregatorV3Interface public priceFeed;
    // Platform fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFeePercentage;
    // Address that collects platform fees
    address public feeCollector;
    
    // Events to log important contract actions
    event PropertySubmitted(uint256 indexed propertyId, address indexed owner, string location, uint256 value, uint256 fractions);
    event PropertyVerified(uint256 indexed propertyId);
    event TokensIssued(uint256 indexed propertyId, uint256 amount);
    event TokensPurchased(uint256 indexed propertyId, address indexed buyer, uint256 amount, uint256 pricePaid);
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    
    /**
     * @dev Constructor to initialize the contract
     * @param _usdcToken Address of the USDC token contract
     * @param _priceFeed Address of the Chainlink price feed contract
     */
    constructor(address _usdcToken, address _priceFeed) ERC1155("") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VERIFIER_ROLE, msg.sender);
        usdcToken = IERC20(_usdcToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        platformFeePercentage = 250; // 2.5%
        feeCollector = msg.sender;
    }
    
    /**
     * @dev Allows a user to submit a new property for tokenization
     * @param _location String description of the property location
     * @param _value Total value of the property in USDC
     * @param _fractions Number of fractions to divide the property into
     */
    function submitProperty(string memory _location, uint256 _value, uint256 _fractions) external {
        require(_value > 0, "Value must be positive");
        require(_fractions > 0, "Fractions must be positive");
        
        propertyCount++;
        properties[propertyCount] = Property({
            owner: msg.sender,
            location: _location,
            value: _value,
            fractions: _fractions,
            isVerified: false,
            isTokenized: false
        });
        
        emit PropertySubmitted(propertyCount, msg.sender, _location, _value, _fractions);
    }
    
    /**
     * @dev Allows a verifier to approve a submitted property
     * @param _propertyId Unique identifier of the property to verify
     */
    function verifyProperty(uint256 _propertyId) external onlyRole(VERIFIER_ROLE) {
        require(_propertyId <= propertyCount, "Property does not exist");
        Property storage property = properties[_propertyId];
        require(!property.isVerified, "Property already verified");
        
        property.isVerified = true;
        emit PropertyVerified(_propertyId);
    }
    
    /**
     * @dev Allows the property owner to issue tokens for a verified property
     * @param _propertyId Unique identifier of the property to tokenize
     */
    function issueTokens(uint256 _propertyId) external {
        Property storage property = properties[_propertyId];
        require(msg.sender == property.owner, "Only owner can issue tokens");
        require(property.isVerified, "Property not verified");
        require(!property.isTokenized, "Tokens already issued");
        
        property.isTokenized = true;
        _mint(property.owner, _propertyId, property.fractions, "");
        
        emit TokensIssued(_propertyId, property.fractions);
    }
    
    /**
     * @dev Allows a user to purchase tokens of a property
     * @param _propertyId Unique identifier of the property to purchase tokens for
     * @param _amount Number of tokens to purchase
     */
    function purchaseTokens(uint256 _propertyId, uint256 _amount) external nonReentrant {
        Property storage property = properties[_propertyId];
        require(property.isTokenized, "Tokens not issued yet");
        require(_amount > 0, "Amount must be positive");
        require(balanceOf(property.owner, _propertyId) >= _amount, "Not enough tokens available");
        
        uint256 tokenPrice = (property.value * _amount) / property.fractions;
        uint256 platformFee = (tokenPrice * platformFeePercentage) / 10000;
        uint256 totalCost = tokenPrice + platformFee;
        
        require(usdcToken.transferFrom(msg.sender, address(this), totalCost), "Transfer failed");
        require(usdcToken.transfer(property.owner, tokenPrice), "Owner payment failed");
        require(usdcToken.transfer(feeCollector, platformFee), "Fee transfer failed");
        
        _safeTransferFrom(property.owner, msg.sender, _propertyId, _amount, "");
        
        emit TokensPurchased(_propertyId, msg.sender, _amount, totalCost);
    }
    
    /**
     * @dev Retrieves all tokenized property listings
     * @return An array of property IDs that have been tokenized
     */
    function getAllListings() external view returns (uint256[] memory) {
        uint256[] memory activeListings = new uint256[](propertyCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= propertyCount; i++) {
            if (properties[i].isTokenized) {
                activeListings[count] = i;
                count++;
            }
        }
        
        // Resize array to remove empty elements
        assembly {
            mstore(activeListings, count)
        }
        
        return activeListings;
    }
    
    /**
     * @dev Retrieves details of a specific property
     * @param _propertyId Unique identifier of the property
     * @return Property struct containing all details of the specified property
     */
    function getPropertyDetails(uint256 _propertyId) external view returns (Property memory) {
        require(_propertyId <= propertyCount, "Property does not exist");
        return properties[_propertyId];
    }
    
    /**
     * @dev Allows the admin to update the platform fee percentage
     * @param _newFeePercentage New fee percentage in basis points (e.g., 250 for 2.5%)
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
        emit PlatformFeeUpdated(_newFeePercentage);
    }
    
    /**
     * @dev Allows the admin to update the fee collector address
     * @param _newFeeCollector Address of the new fee collector
     */
    function updateFeeCollector(address _newFeeCollector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFeeCollector != address(0), "Invalid address");
        feeCollector = _newFeeCollector;
        emit FeeCollectorUpdated(_newFeeCollector);
    }
    
    /**
     * @dev Retrieves the latest price from the Chainlink price feed
     * @return The latest price as an int
     * @notice This function is not currently used in the contract but can be
     * integrated for dynamic pricing in future iterations
     */
    function getLatestPrice() public view returns (int) {
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return price;
    }
    
    /**
     * @dev Override required by Solidity for ERC1155 and AccessControl compatibility
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements interfaceId, false otherwise
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