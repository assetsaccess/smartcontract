// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    struct Property {
        address owner;
        string location;
        uint256 value;
        uint256 fractions;
        bool isVerified;
        bool isTokenized;
    }
    
    mapping(uint256 => Property) public properties;
    uint256 public propertyCount;
    
    IERC20 public usdcToken;
    AggregatorV3Interface public priceFeed;
    uint256 public platformFeePercentage;
    address public feeCollector;
    
    event PropertySubmitted(uint256 indexed propertyId, address indexed owner, string location, uint256 value, uint256 fractions);
    event PropertyVerified(uint256 indexed propertyId);
    event TokensIssued(uint256 indexed propertyId, uint256 amount);
    event TokensPurchased(uint256 indexed propertyId, address indexed buyer, uint256 amount, uint256 pricePaid);
    event PlatformFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    
    constructor() ERC1155("") {
        // _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // _setupRole(VERIFIER_ROLE, msg.sender);
        usdcToken = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // USDC on Sepolia
        priceFeed = AggregatorV3Interface(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165); // USDC/USD price feed on Sepolia
        platformFeePercentage = 250; // 2.5%
        feeCollector = msg.sender;
    }
    
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
    
    function verifyProperty(uint256 _propertyId) external onlyRole(VERIFIER_ROLE) {
        require(_propertyId <= propertyCount, "Property does not exist");
        Property storage property = properties[_propertyId];
        require(!property.isVerified, "Property already verified");
        
        property.isVerified = true;
        emit PropertyVerified(_propertyId);
    }
    
    function issueTokens(uint256 _propertyId) external {
        Property storage property = properties[_propertyId];
        require(msg.sender == property.owner, "Only owner can issue tokens");
        require(property.isVerified, "Property not verified");
        require(!property.isTokenized, "Tokens already issued");
        
        property.isTokenized = true;
        _mint(property.owner, _propertyId, property.fractions, "");
        
        emit TokensIssued(_propertyId, property.fractions);
    }
    
    function purchaseTokens(uint256 _propertyId, uint256 _amount) external nonReentrant {
        Property storage property = properties[_propertyId];
        require(property.isTokenized, "Tokens not issued yet");
        require(_amount > 0, "Amount must be positive");
        require(balanceOf(property.owner, _propertyId) >= _amount, "Not enough tokens available");
        
        uint256 tokenPrice = (property.value * _amount) / property.fractions;
        uint256 usdcAmount = getUSDCAmount(tokenPrice);
        uint256 platformFee = (usdcAmount * platformFeePercentage) / 10000;
        uint256 totalCost = usdcAmount + platformFee;
        
        require(usdcToken.transferFrom(msg.sender, address(this), totalCost), "Transfer failed");
        require(usdcToken.transfer(property.owner, usdcAmount), "Owner payment failed");
        require(usdcToken.transfer(feeCollector, platformFee), "Fee transfer failed");
        
        _safeTransferFrom(property.owner, msg.sender, _propertyId, _amount, "");
        
        emit TokensPurchased(_propertyId, msg.sender, _amount, totalCost);
    }
    
    function getAllListings() external view returns (uint256[] memory) {
        uint256[] memory activeListings = new uint256[](propertyCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= propertyCount; i++) {
            if (properties[i].isTokenized) {
                activeListings[count] = i;
                count++;
            }
        }
        
        assembly {
            mstore(activeListings, count)
        }
        
        return activeListings;
    }
    
    function getPropertyDetails(uint256 _propertyId) external view returns (Property memory) {
        require(_propertyId <= propertyCount, "Property does not exist");
        return properties[_propertyId];
    }
    
    function updatePlatformFee(uint256 _newFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
        emit PlatformFeeUpdated(_newFeePercentage);
    }
    
    function updateFeeCollector(address _newFeeCollector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFeeCollector != address(0), "Invalid address");
        feeCollector = _newFeeCollector;
        emit FeeCollectorUpdated(_newFeeCollector);
    }
    
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
    
    function getUSDCAmount(uint256 _usdAmount) public view returns (uint256) {
        int latestPrice = getLatestPrice();
        require(latestPrice > 0, "Invalid price feed");
        
        // Convert the USD amount to USDC
        // The price feed returns the price with 8 decimals, and USDC has 6 decimals
        return (_usdAmount * 1e6 * 1e8) / uint256(latestPrice) / 1e8;
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}