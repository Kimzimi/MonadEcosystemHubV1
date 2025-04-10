// SPDX-License-Identifier: MIT
// PART 1/12 - MonadEcosystemHubV1
// A comprehensive ecosystem hub for Monad blockchain
// This contract aims to provide multiple useful functionalities while approaching the 128KB size limit

pragma solidity ^0.8.24;

// Import OpenZeppelin contracts for standard implementations
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/**
 * @title MonadEcosystemHubV1
 * @dev A comprehensive hub for Monad blockchain ecosystem providing multiple functionalities:
 * - Resource Management
 * - Digital Asset Exchange
 * - Voting & Governance
 * - Games & Rewards
 * - Data & Analytics
 * - Security Features
 */
 // Library containing the isContract function (Workaround)
library AddressUtils {
    function isContract(address account) internal view returns (bool) {
        // This is the core logic from OpenZeppelin's Address library
        // It checks if an address has code deployed to it.
        return account.code.length > 0;
    }
}

contract MonadEcosystemHubV1 is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using ECDSA for bytes32;

    // ==================== CONSTANTS ====================
    
    // Version information
    string public constant VERSION = "1.0.0";
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    
    // Fee related constants
    uint256 public constant MAX_FEE = 1000; // 10% max fee (10% = 1000 / 10000)
    uint256 public constant FEE_DENOMINATOR = 10000; // Denominator for fee calculations
    
    // Time related constants
    uint256 public constant MIN_LOCK_PERIOD = 1 days;
    uint256 public constant MAX_LOCK_PERIOD = 365 days;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant CLAIM_PERIOD = 30 days;
    
    // Game related constants
    uint256 public constant MAX_RANDOM_RANGE = 10000;
    uint256 public constant MIN_BET_AMOUNT = 0.001 ether;
    uint256 public constant MAX_BET_AMOUNT = 100 ether;
    
    // Data storage limits
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
    uint256 public constant MAX_URI_LENGTH = 200;
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    // Security constants
    uint256 public constant EMERGENCY_TIMELOCK = 24 hours;
    
    // ==================== STATE VARIABLES ====================
    
    // Contract metadata
    string public name = "Monad Ecosystem Hub";
    string public symbol = "MEH";
    string public baseURI;
    
    // Fee configuration
    uint256 public platformFee = 250; // 2.5% default fee
    address public feeCollector;
    
    // Counters for various entities
    Counters.Counter private _resourceIdCounter;
    Counters.Counter private _exchangeIdCounter;
    Counters.Counter private _proposalIdCounter;
    Counters.Counter private _gameIdCounter;
    Counters.Counter private _datasetIdCounter;
    
    // Status tracking
    bool public emergencyMode = false;
    uint256 public emergencyTimestamp;
    
    // ==================== MAPPINGS ====================
    
    // User related mappings
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public userReputation;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public userBalances;
    mapping(address => mapping(address => uint256)) public tokenBalances; // user => token => amount
    mapping(address => EnumerableSet.AddressSet) private userTokens;
    
    // Resource management mappings
    mapping(uint256 => Resource) public resources;
    mapping(uint256 => mapping(address => uint256)) public resourceAllocation;
    mapping(address => EnumerableSet.UintSet) private ownedResources;
    
    // Exchange related mappings
    mapping(uint256 => Exchange) public exchanges;
    mapping(uint256 => mapping(address => uint256)) public exchangeParticipation;
    mapping(address => EnumerableSet.UintSet) private userExchanges;
    
    // Governance related mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => EnumerableSet.UintSet) private userVotedProposals;
    
    // Game related mappings
    mapping(uint256 => Game) public games;
    mapping(uint256 => mapping(address => uint256)) public gameBets;
    mapping(address => EnumerableSet.UintSet) private userGames;
    
    // Data related mappings
    mapping(uint256 => Dataset) public datasets;
    mapping(uint256 => mapping(address => bool)) public datasetAccess;
    mapping(address => EnumerableSet.UintSet) private ownedDatasets;
    
    // Security related mappings
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public lastActionTimestamp;
    mapping(address => uint256) public actionCount;
    mapping(bytes32 => bool) public isOperationExecuted;
    mapping(bytes32 => uint256) public operationTimestamps;
    
    // ==================== STRUCTS ====================
    
    // User related structs
    struct UserProfile {
        string name;
        string description;
        string avatarURI;
        uint256 registrationTime;
        uint256 lastActivityTime;
        UserPreferences preferences;
        uint256[] badges;
    }
    
    struct UserPreferences {
        bool receiveNotifications;
        bool isPublicProfile;
        uint8 privacyLevel;
        address[] trustedContacts;
        string[] favoriteCategories;
    }
    
    // Resource management structs
    struct Resource {
        string name;
        string description;
        ResourceType resourceType;
        address owner;
        uint256 creationTime;
        uint256 updateTime;
        uint256 totalSupply;
        uint256 availableSupply;
        uint256 price;
        bool isActive;
        string metadataURI;
        ResourceProperties properties;
    }
    
    struct ResourceProperties {
        bool isTransferable;
        bool isBurnable;
        bool isLockable;
        uint256 maxPerUser;
        uint256 lockPeriod;
        address[] allowedUsers;
    }
    
    // Exchange related structs
    struct Exchange {
        string name;
        string description;
        ExchangeType exchangeType;
        address creator;
        uint256 creationTime;
        uint256 expirationTime;
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        bool isFulfilled;
        bool isCancelled;
        ExchangeConditions conditions;
    }
    
    struct ExchangeConditions {
        address[] allowedParticipants;
        uint256 minParticipation;
        uint256 maxParticipation;
        bool requiresWhitelist;
        bool allowPartialFills;
        uint256 deadline;
    }
    
    // Governance related structs
    struct Proposal {
        string title;
        string description;
        address proposer;
        uint256 creationTime;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        ProposalStatus status;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bytes[] actions;
        address[] targets;
        uint256[] values;
        string[] signatures;
        ProposalParameters parameters;
    }
    
    struct ProposalParameters {
        uint256 quorum;
        uint256 threshold;
        bool isEmergency;
        address[] validators;
        string[] categories;
        string metadataURI;
    }
    
    struct Vote {
        VoteType voteType;
        uint256 weight;
        string reason;
        uint256 timestamp;
    }
    
    // Game related structs
    struct Game {
        string name;
        string description;
        GameType gameType;
        address creator;
        uint256 creationTime;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 totalPool;
        uint256 minBet;
        uint256 maxBet;
        uint256[] rewards;
        address[] winners;
        GameParameters parameters;
    }
    
    struct GameParameters {
        uint256 winProbability;
        uint256 maxPlayers;
        uint256 roundDuration;
        bool allowRebuy;
        uint256 rakePercentage;
        string[] categories;
        uint256[] winMultipliers;
    }
    
    // Data related structs
    struct Dataset {
        string name;
        string description;
        DatasetType datasetType;
        address owner;
        uint256 creationTime;
        uint256 updateTime;
        bool isPublic;
        uint256 accessPrice;
        string[] tags;
        string contentURI;
        DatasetParameters parameters;
    }
    
    struct DatasetParameters {
        uint256 size;
        string format;
        uint256 version;
        string license;
        string[] contributors;
        uint256 updateFrequency;
        bool isVerified;
    }
    
    // Security related structs
    struct SecurityConfig {
        uint256 maxActionsPerDay;
        uint256 maxTransactionValue;
        bool requireMultisig;
        address[] guardians;
        uint8 requiredConfirmations;
        bool hasTimeLock;
        uint256 timelock;
    }
    
    // ==================== ENUMS ====================
    
    enum ResourceType { FUNGIBLE, NON_FUNGIBLE, SERVICE, COMPUTING, STORAGE, BANDWIDTH }
    enum ExchangeType { SELL, BUY, SWAP, AUCTION, RAFFLE, BATCH }
    enum ProposalStatus { PENDING, ACTIVE, SUCCEEDED, DEFEATED, EXECUTED, CANCELED, EXPIRED }
    enum VoteType { AGAINST, FOR, ABSTAIN }
    enum GameType { LOTTERY, PREDICTION, CHALLENGE, TOURNAMENT, DAILY, ACHIEVEMENT }
    enum DatasetType { FINANCIAL, SOCIAL, TECHNICAL, SCIENTIFIC, EDUCATIONAL, CREATIVE }
    
    // ==================== EVENTS ====================
    
    // User related events
    event UserRegistered(address indexed user, string name, uint256 timestamp);
    event UserProfileUpdated(address indexed user, string name, uint256 timestamp);
    event UserBalanceChanged(address indexed user, uint256 oldBalance, uint256 newBalance);
    event ReputationChanged(address indexed user, uint256 oldReputation, uint256 newReputation);
    
    // Resource related events
    event ResourceCreated(uint256 indexed resourceId, address indexed creator, string name);
    event ResourceUpdated(uint256 indexed resourceId, address indexed updater, uint256 timestamp);
    event ResourceTransferred(uint256 indexed resourceId, address indexed from, address indexed to);
    event ResourceAllocated(uint256 indexed resourceId, address indexed user, uint256 amount);
    
    // Exchange related events
    event ExchangeCreated(uint256 indexed exchangeId, address indexed creator, ExchangeType exchangeType);
    event ExchangeParticipated(uint256 indexed exchangeId, address indexed participant, uint256 amount);
    event ExchangeFulfilled(uint256 indexed exchangeId, address indexed fulfiller, uint256 timestamp);
    event ExchangeCancelled(uint256 indexed exchangeId, address indexed canceller, uint256 timestamp);
    
    // Governance related events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType voteType, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor, uint256 timestamp);
    event ProposalCancelled(uint256 indexed proposalId, address indexed canceller, uint256 timestamp);
    
    // Game related events
    event GameCreated(uint256 indexed gameId, address indexed creator, string name);
    event GameStarted(uint256 indexed gameId, uint256 timestamp, uint256 totalPool);
    event GameEnded(uint256 indexed gameId, uint256 timestamp, address[] winners);
    event BetPlaced(uint256 indexed gameId, address indexed player, uint256 amount);
    
    // Data related events
    event DatasetCreated(uint256 indexed datasetId, address indexed creator, string name);
    event DatasetUpdated(uint256 indexed datasetId, address indexed updater, uint256 timestamp);
    event DatasetAccessed(uint256 indexed datasetId, address indexed accessor, uint256 timestamp);
    event DataContribution(uint256 indexed datasetId, address indexed contributor, uint256 timestamp);
    
    // Security related events
    event EmergencyModeActivated(address indexed activator, uint256 timestamp);
    event EmergencyModeDeactivated(address indexed deactivator, uint256 timestamp);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event SecurityBreach(address indexed account, string breachType, uint256 timestamp);
    
    // Finance related events
    event FeePaid(address indexed payer, uint256 amount, string purpose);
    event FeeCollected(address indexed collector, uint256 amount);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);
    
    // ==================== CONSTRUCTOR ====================
    
    constructor(address _feeCollector) Ownable(msg.sender) {
        feeCollector = _feeCollector;
        baseURI = "https://api.monad-ecosystem.io/metadata/";
        
        // Initialize contract with the creator as the owner
        _transferOwnership(msg.sender);
        
        // Whitelist the contract creator
        isWhitelisted[msg.sender] = true;
        
        // Initialize Pause control
        _pause();
        _unpause();
    }
    
    // ==================== MODIFIERS ====================
    
    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }
    
    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "Account not whitelisted");
        _;
    }
    
    modifier notInEmergencyMode() {
        require(!emergencyMode, "Contract is in emergency mode");
        _;
    }
    
    modifier onlyResourceOwner(uint256 resourceId) {
        require(resources[resourceId].owner == msg.sender, "Not the resource owner");
        _;
    }
    
    modifier onlyProposalProposer(uint256 proposalId) {
        require(proposals[proposalId].proposer == msg.sender, "Not the proposal proposer");
        _;
    }
    
    modifier onlyGameCreator(uint256 gameId) {
        require(games[gameId].creator == msg.sender, "Not the game creator");
        _;
    }
    
    modifier onlyDatasetOwner(uint256 datasetId) {
        require(datasets[datasetId].owner == msg.sender, "Not the dataset owner");
        _;
    }
    
    modifier validResourceId(uint256 resourceId) {
        require(resourceId > 0 && resourceId <= _resourceIdCounter.current(), "Invalid resource ID");
        _;
    }
    
    modifier validExchangeId(uint256 exchangeId) {
        require(exchangeId > 0 && exchangeId <= _exchangeIdCounter.current(), "Invalid exchange ID");
        _;
    }
    
    modifier validProposalId(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalIdCounter.current(), "Invalid proposal ID");
        _;
    }
    
    modifier validGameId(uint256 gameId) {
        require(gameId > 0 && gameId <= _gameIdCounter.current(), "Invalid game ID");
        _;
    }
    
    modifier validDatasetId(uint256 datasetId) {
        require(datasetId > 0 && datasetId <= _datasetIdCounter.current(), "Invalid dataset ID");
        _;
    }
    
    modifier activeResource(uint256 resourceId) {
        require(resources[resourceId].isActive, "Resource is not active");
        _;
    }
    
    modifier activeGame(uint256 gameId) {
        require(games[gameId].isActive, "Game is not active");
        _;
    }
    
    modifier withinBatchLimit(uint256 size) {
        require(size <= MAX_BATCH_SIZE, "Exceeds maximum batch size");
        _;
    }
    
    modifier feeCheck(uint256 fee) {
        require(fee <= MAX_FEE, "Fee exceeds maximum");
        _;
    }
    
    modifier securityCheck() {
        // Update user action counter and timestamp
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lastActionDay = lastActionTimestamp[msg.sender] / 1 days;
        
        if (currentDay > lastActionDay) {
            actionCount[msg.sender] = 1;
        } else {
            actionCount[msg.sender] += 1;
        }
        
        lastActionTimestamp[msg.sender] = block.timestamp;
        _;
    }
    
    // ==================== INITIALIZATION & CONFIGURATION FUNCTIONS ====================
    
    // Initialization function to be called after deployment
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external onlyOwner {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
    }
    
    // Update fee collector address
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "Invalid fee collector address");
        feeCollector = _feeCollector;
    }
    
    // Update platform fee percentage
    function setPlatformFee(uint256 _platformFee) external onlyOwner feeCheck(_platformFee) {
        platformFee = _platformFee;
    }
    
    // Update base URI for metadata
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }
    
    // Toggle emergency mode
    function toggleEmergencyMode() external onlyOwner {
        if (!emergencyMode) {
            emergencyMode = true;
            emergencyTimestamp = block.timestamp;
            emit EmergencyModeActivated(msg.sender, block.timestamp);
        } else {
            require(block.timestamp >= emergencyTimestamp + EMERGENCY_TIMELOCK, "Emergency timelock not expired");
            emergencyMode = false;
            emit EmergencyModeDeactivated(msg.sender, block.timestamp);
        }
    }
    
    // Update whitelist status for an account
    function updateWhitelist(address account, bool status) external onlyOwner {
        isWhitelisted[account] = status;
        emit WhitelistUpdated(account, status);
    }
    
    // Batch update whitelist for multiple accounts
    function batchUpdateWhitelist(address[] calldata accounts, bool status) external onlyOwner withinBatchLimit(accounts.length) {
        for (uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = status;
            emit WhitelistUpdated(accounts[i], status);
        }
    }
    
    // Pause all contract functions
    function pause() external onlyOwner {
        _pause();
    }
    
    // Unpause all contract functions
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ==================== USER MANAGEMENT FUNCTIONS ====================
    
    // Register a new user
    function registerUser(string memory _name, string memory _description, string memory _avatarURI) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(!isRegistered[msg.sender], "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        isRegistered[msg.sender] = true;
        userReputation[msg.sender] = 100; // Initial reputation score
        
        UserProfile storage profile = userProfiles[msg.sender];
        profile.name = _name;
        profile.description = _description;
        profile.avatarURI = _avatarURI;
        profile.registrationTime = block.timestamp;
        profile.lastActivityTime = block.timestamp;
        
        // Initialize empty preferences
        profile.preferences.receiveNotifications = true;
        profile.preferences.isPublicProfile = true;
        profile.preferences.privacyLevel = 1;
        
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }
    
    // Update user profile
    function updateUserProfile(string memory _name, string memory _description, string memory _avatarURI) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        UserProfile storage profile = userProfiles[msg.sender];
        profile.name = _name;
        profile.description = _description;
        profile.avatarURI = _avatarURI;
        profile.lastActivityTime = block.timestamp;
        
        emit UserProfileUpdated(msg.sender, _name, block.timestamp);
    }
    
    // Update user preferences
    function updateUserPreferences(
        bool _receiveNotifications,
        bool _isPublicProfile,
        uint8 _privacyLevel,
        address[] calldata _trustedContacts,
        string[] calldata _favoriteCategories
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        withinBatchLimit(_trustedContacts.length)
        withinBatchLimit(_favoriteCategories.length)
    {
        require(_privacyLevel <= 3, "Invalid privacy level");
        
        UserPreferences storage prefs = userProfiles[msg.sender].preferences;
        prefs.receiveNotifications = _receiveNotifications;
        prefs.isPublicProfile = _isPublicProfile;
        prefs.privacyLevel = _privacyLevel;
        
        // Clear and update trusted contacts
        delete prefs.trustedContacts;
        for (uint256 i = 0; i < _trustedContacts.length; i++) {
            prefs.trustedContacts.push(_trustedContacts[i]);
        }
        
        // Clear and update favorite categories
        delete prefs.favoriteCategories;
        for (uint256 i = 0; i < _favoriteCategories.length; i++) {
            prefs.favoriteCategories.push(_favoriteCategories[i]);
        }
        
        userProfiles[msg.sender].lastActivityTime = block.timestamp;
    }
    
    // Add badge to user profile
    function addUserBadge(address user, uint256 badgeId) 
        external 
        onlyOwner 
    {
        require(isRegistered[user], "User not registered");
        userProfiles[user].badges.push(badgeId);
        userProfiles[user].lastActivityTime = block.timestamp;
    }
    
    // Remove badge from user profile
    function removeUserBadge(address user, uint256 badgeId) 
        external 
        onlyOwner 
    {
        require(isRegistered[user], "User not registered");
        
        UserProfile storage profile = userProfiles[user];
        uint256[] storage badges = profile.badges;
        
        for (uint256 i = 0; i < badges.length; i++) {
            if (badges[i] == badgeId) {
                // Swap with the last element and pop
                badges[i] = badges[badges.length - 1];
                badges.pop();
                break;
            }
        }
        
        profile.lastActivityTime = block.timestamp;
    }
    
    // Update user reputation
    function updateUserReputation(address user, uint256 newReputation) 
        external 
        onlyOwner 
    {
        require(isRegistered[user], "User not registered");
        
        uint256 oldReputation = userReputation[user];
        userReputation[user] = newReputation;
        
        emit ReputationChanged(user, oldReputation, newReputation);
    }
    
    // Deposit native token to user balance
    function deposit() 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        uint256 oldBalance = userBalances[msg.sender];
        userBalances[msg.sender] = oldBalance.add(msg.value);
        
        emit UserBalanceChanged(msg.sender, oldBalance, userBalances[msg.sender]);
    }
    
    // Withdraw native token from user balance
    function withdraw(uint256 amount) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(userBalances[msg.sender] >= amount, "Insufficient balance");
        
        uint256 oldBalance = userBalances[msg.sender];
        userBalances[msg.sender] = oldBalance.sub(amount);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit UserBalanceChanged(msg.sender, oldBalance, userBalances[msg.sender]);
    }
    
    // Deposit ERC20 token
    function depositToken(address tokenAddress, uint256 amount) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(tokenAddress != address(0), "Invalid token address");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].add(amount);
        userTokens[msg.sender].add(tokenAddress);
        
        emit TokenDeposited(msg.sender, tokenAddress, amount);
    }
    
    // Withdraw ERC20 token
    function withdrawToken(address tokenAddress, uint256 amount) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenBalances[msg.sender][tokenAddress] >= amount, "Insufficient token balance");
        
        tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].sub(amount);
        
        if (tokenBalances[msg.sender][tokenAddress] == 0) {
            userTokens[msg.sender].remove(tokenAddress);
        }
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit TokenWithdrawn(msg.sender, tokenAddress, amount);
    }
    
// END OF PART 1/12 - CONTINUE TO PART 2/12

// SPDX-License-Identifier: MIT
// PART 2/12 - MonadEcosystemHubV1
// Resource Management & Exchange Functions
// Continues from PART 1/12

// CONTINUED FROM PART 1/12

    // ==================== RESOURCE MANAGEMENT FUNCTIONS ====================
    
    // Create a new resource
    function createResource(
        string memory _name,
        string memory _description,
        ResourceType _resourceType,
        uint256 _totalSupply,
        uint256 _price,
        string memory _metadataURI,
        ResourceProperties memory _properties
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(bytes(_metadataURI).length <= MAX_URI_LENGTH, "URI too long");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        
        // Increment resource ID counter
        _resourceIdCounter.increment();
        uint256 newResourceId = _resourceIdCounter.current();
        
        // Create new resource
        Resource storage newResource = resources[newResourceId];
        newResource.name = _name;
        newResource.description = _description;
        newResource.resourceType = _resourceType;
        newResource.owner = msg.sender;
        newResource.creationTime = block.timestamp;
        newResource.updateTime = block.timestamp;
        newResource.totalSupply = _totalSupply;
        newResource.availableSupply = _totalSupply;
        newResource.price = _price;
        newResource.isActive = true;
        newResource.metadataURI = _metadataURI;
        newResource.properties = _properties;
        
        // Add to user's owned resources
        ownedResources[msg.sender].add(newResourceId);
        
        // Calculate and charge platform fee if resource has a price
        if (_price > 0) {
            uint256 platformFeeAmount = (_price.mul(platformFee)).div(FEE_DENOMINATOR);
            require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
            
            userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
            
            emit FeePaid(msg.sender, platformFeeAmount, "Resource Creation");
        }
        
        emit ResourceCreated(newResourceId, msg.sender, _name);
    }
    
    // Update resource details
    function updateResource(
        uint256 resourceId,
        string memory _name,
        string memory _description,
        uint256 _price,
        string memory _metadataURI,
        bool _isActive
    ) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(bytes(_metadataURI).length <= MAX_URI_LENGTH, "URI too long");
        
        Resource storage resource = resources[resourceId];
        resource.name = _name;
        resource.description = _description;
        resource.price = _price;
        resource.metadataURI = _metadataURI;
        resource.isActive = _isActive;
        resource.updateTime = block.timestamp;
        
        emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
    }
    
    // Update resource properties
    function updateResourceProperties(
        uint256 resourceId,
        ResourceProperties memory _properties
    ) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        nonReentrant 
        securityCheck 
    {
        Resource storage resource = resources[resourceId];
        resource.properties = _properties;
        resource.updateTime = block.timestamp;
        
        emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
    }
    
    // Transfer resource ownership
    function transferResource(uint256 resourceId, address newOwner) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        nonReentrant 
        securityCheck 
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(isRegistered[newOwner], "New owner not registered");
        require(newOwner != msg.sender, "Cannot transfer to self");
        
        Resource storage resource = resources[resourceId];
        
        // Remove from current owner
        ownedResources[msg.sender].remove(resourceId);
        
        // Add to new owner
        resource.owner = newOwner;
        resource.updateTime = block.timestamp;
        ownedResources[newOwner].add(resourceId);
        
        emit ResourceTransferred(resourceId, msg.sender, newOwner);
    }
    
    // Allocate resource to a user
    function allocateResource(uint256 resourceId, address user, uint256 amount) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        activeResource(resourceId) 
        nonReentrant 
        securityCheck 
    {
        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");
        require(amount > 0, "Amount must be greater than 0");
        
        Resource storage resource = resources[resourceId];
        require(resource.availableSupply >= amount, "Insufficient available supply");
        
        // Check if user is allowed to receive this resource
        if (resource.properties.allowedUsers.length > 0) {
            bool isAllowed = false;
            for (uint256 i = 0; i < resource.properties.allowedUsers.length; i++) {
                if (resource.properties.allowedUsers[i] == user) {
                    isAllowed = true;
                    break;
                }
            }
            require(isAllowed, "User not allowed to receive this resource");
        }
        
        // Check maximum per user limit
        if (resource.properties.maxPerUser > 0) {
            require(
                resourceAllocation[resourceId][user] + amount <= resource.properties.maxPerUser,
                "Exceeds maximum allocation per user"
            );
        }
        
        // Update resource allocation
        resourceAllocation[resourceId][user] = resourceAllocation[resourceId][user].add(amount);
        resource.availableSupply = resource.availableSupply.sub(amount);
        
        emit ResourceAllocated(resourceId, user, amount);
    }
    
    // Return resource from a user
    function returnResource(uint256 resourceId, address user, uint256 amount) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(
            msg.sender == user || msg.sender == resources[resourceId].owner, 
            "Only resource owner or allocated user can return"
        );
        require(amount > 0, "Amount must be greater than 0");
        
        Resource storage resource = resources[resourceId];
        require(resourceAllocation[resourceId][user] >= amount, "Insufficient allocated amount");
        
        // Update resource allocation
        resourceAllocation[resourceId][user] = resourceAllocation[resourceId][user].sub(amount);
        resource.availableSupply = resource.availableSupply.add(amount);
        
        emit ResourceAllocated(resourceId, user, amount);
    }
    
    // Get user's allocated resources
    function getUserResourceAllocation(uint256 resourceId, address user) 
        external 
        view 
        returns (uint256) 
    {
        return resourceAllocation[resourceId][user];
    }
    
    // Get all resources owned by a user
    function getUserOwnedResources(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = ownedResources[user].length();
        uint256[] memory resourceIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            resourceIds[i] = ownedResources[user].at(i);
        }
        
        return resourceIds;
    }
    
    // Batch allocate resources
    function batchAllocateResource(
        uint256 resourceId, 
        address[] calldata users, 
        uint256[] calldata amounts
    ) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        activeResource(resourceId) 
        nonReentrant 
        securityCheck 
        withinBatchLimit(users.length)
    {
        require(users.length == amounts.length, "Arrays length mismatch");
        
        Resource storage resource = resources[resourceId];
        uint256 totalAmount = 0;
        
        // Calculate total amount and check it against available supply
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount.add(amounts[i]);
        }
        require(resource.availableSupply >= totalAmount, "Insufficient available supply");
        
        // Process allocation for each user
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 amount = amounts[i];
            
            require(user != address(0), "Invalid user address");
            require(isRegistered[user], "User not registered");
            require(amount > 0, "Amount must be greater than 0");
            
            // Check if user is allowed to receive this resource
            if (resource.properties.allowedUsers.length > 0) {
                bool isAllowed = false;
                for (uint256 j = 0; j < resource.properties.allowedUsers.length; j++) {
                    if (resource.properties.allowedUsers[j] == user) {
                        isAllowed = true;
                        break;
                    }
                }
                require(isAllowed, "User not allowed to receive this resource");
            }
            
            // Check maximum per user limit
            if (resource.properties.maxPerUser > 0) {
                require(
                    resourceAllocation[resourceId][user] + amount <= resource.properties.maxPerUser,
                    "Exceeds maximum allocation per user"
                );
            }
            
            // Update resource allocation
            resourceAllocation[resourceId][user] = resourceAllocation[resourceId][user].add(amount);
            emit ResourceAllocated(resourceId, user, amount);
        }
        
        // Update available supply
        resource.availableSupply = resource.availableSupply.sub(totalAmount);
    }
    
    // ==================== EXCHANGE FUNCTIONS ====================
    
    // Create a new exchange
    function createExchange(
        string memory _name,
        string memory _description,
        ExchangeType _exchangeType,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        ExchangeConditions memory _conditions
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(_amount > 0, "Amount must be greater than 0");
        
        // Validate exchange conditions
        if (_conditions.deadline > 0) {
            require(_conditions.deadline > block.timestamp, "Deadline must be in the future");
        }
        
        // For token exchanges, validate token ownership and approval
        if (_tokenAddress != address(0)) {
            if (_exchangeType == ExchangeType.SELL || _exchangeType == ExchangeType.SWAP) {
                // For ERC20 tokens
                if (_tokenId == 0) {
                    IERC20 token = IERC20(_tokenAddress);
                    require(
                        token.balanceOf(msg.sender) >= _amount, 
                        "Insufficient token balance"
                    );
                    require(
                        token.allowance(msg.sender, address(this)) >= _amount, 
                        "Insufficient token allowance"
                    );
                }
                // For ERC721 tokens
                else {
                    IERC721 nft = IERC721(_tokenAddress);
                    require(
                        nft.ownerOf(_tokenId) == msg.sender, 
                        "Not the NFT owner"
                    );
                    require(
                        nft.isApprovedForAll(msg.sender, address(this)) || 
                        nft.getApproved(_tokenId) == address(this), 
                        "NFT not approved"
                    );
                }
            }
        }
        
        // Increment exchange ID counter
        _exchangeIdCounter.increment();
        uint256 newExchangeId = _exchangeIdCounter.current();
        
        // Create new exchange
        Exchange storage newExchange = exchanges[newExchangeId];
        newExchange.name = _name;
        newExchange.description = _description;
        newExchange.exchangeType = _exchangeType;
        newExchange.creator = msg.sender;
        newExchange.creationTime = block.timestamp;
        newExchange.tokenAddress = _tokenAddress;
        newExchange.tokenId = _tokenId;
        newExchange.amount = _amount;
        newExchange.price = _price;
        newExchange.isFulfilled = false;
        newExchange.isCancelled = false;
        newExchange.conditions = _conditions;
        
        // If deadline is not set, set a default expiration (30 days)
        if (_conditions.deadline == 0) {
            newExchange.expirationTime = block.timestamp + 30 days;
        } else {
            newExchange.expirationTime = _conditions.deadline;
        }
        
        // Add to user's exchanges
        userExchanges[msg.sender].add(newExchangeId);
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = (_price.mul(platformFee)).div(FEE_DENOMINATOR);
        require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        emit FeePaid(msg.sender, platformFeeAmount, "Exchange Creation");
        emit ExchangeCreated(newExchangeId, msg.sender, _exchangeType);
    }
    
    // Participate in an exchange
    function participateInExchange(uint256 exchangeId, uint256 amount) 
        external 
        payable 
        whenNotPaused 
        validExchangeId(exchangeId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Exchange storage exchange = exchanges[exchangeId];
        
        require(!exchange.isFulfilled, "Exchange already fulfilled");
        require(!exchange.isCancelled, "Exchange cancelled");
        require(block.timestamp < exchange.expirationTime, "Exchange expired");
        
        // Check if user is allowed to participate
        if (exchange.conditions.requiresWhitelist) {
            require(isWhitelisted[msg.sender], "User not whitelisted");
        }
        
        // Check if specific participants are allowed
        if (exchange.conditions.allowedParticipants.length > 0) {
            bool isAllowed = false;
            for (uint256 i = 0; i < exchange.conditions.allowedParticipants.length; i++) {
                if (exchange.conditions.allowedParticipants[i] == msg.sender) {
                    isAllowed = true;
                    break;
                }
            }
            require(isAllowed, "User not allowed to participate");
        }
        
        // Validate amount
        require(amount > 0, "Amount must be greater than 0");
        
        if (exchange.conditions.minParticipation > 0) {
            require(amount >= exchange.conditions.minParticipation, "Amount below minimum participation");
        }
        
        if (exchange.conditions.maxParticipation > 0) {
            require(amount <= exchange.conditions.maxParticipation, "Amount above maximum participation");
        }
        
        uint256 remainingAmount = exchange.amount - exchangeParticipation[exchangeId][msg.sender];
        
        if (!exchange.conditions.allowPartialFills) {
            require(amount == exchange.amount, "Must fulfill entire exchange");
        } else {
            require(amount <= remainingAmount, "Amount exceeds remaining exchange amount");
        }
        
        // Handle different exchange types
        if (exchange.exchangeType == ExchangeType.SELL) {
            // Seller is offering tokens for ETH/MONAD
            uint256 paymentAmount = (exchange.price.mul(amount)).div(exchange.amount);
            require(msg.value >= paymentAmount, "Insufficient payment");
            
            // Transfer tokens from contract to buyer
            if (exchange.tokenAddress != address(0)) {
                if (exchange.tokenId == 0) {
                    // ERC20 transfer
                    IERC20 token = IERC20(exchange.tokenAddress);
                    require(
                        tokenBalances[exchange.creator][exchange.tokenAddress] >= amount,
                        "Seller has insufficient token balance"
                    );
                    
                    // Update token balances
                    tokenBalances[exchange.creator][exchange.tokenAddress] = 
                        tokenBalances[exchange.creator][exchange.tokenAddress].sub(amount);
                    
                    tokenBalances[msg.sender][exchange.tokenAddress] = 
                        tokenBalances[msg.sender][exchange.tokenAddress].add(amount);
                    
                    userTokens[msg.sender].add(exchange.tokenAddress);
                } else {
                    // ERC721 transfer
                    IERC721 nft = IERC721(exchange.tokenAddress);
                    nft.safeTransferFrom(exchange.creator, msg.sender, exchange.tokenId);
                }
            }
            
            // Update seller's balance
            userBalances[exchange.creator] = userBalances[exchange.creator].add(paymentAmount);
            
            // Return excess payment
            if (msg.value > paymentAmount) {
                (bool success, ) = msg.sender.call{value: msg.value - paymentAmount}("");
                require(success, "Refund failed");
            }
        } else if (exchange.exchangeType == ExchangeType.BUY) {
            // Buyer is offering ETH/MONAD for tokens
            if (exchange.tokenAddress != address(0)) {
                if (exchange.tokenId == 0) {
                    // ERC20 transfer
                    IERC20 token = IERC20(exchange.tokenAddress);
                    require(
                        token.transferFrom(msg.sender, exchange.creator, amount), 
                        "Token transfer failed"
                    );
                } else {
                    // ERC721 transfer
                    IERC721 nft = IERC721(exchange.tokenAddress);
                    nft.safeTransferFrom(msg.sender, exchange.creator, exchange.tokenId);
                }
            }
            
            // Calculate payment
            uint256 paymentAmount = (exchange.price.mul(amount)).div(exchange.amount);
            require(userBalances[exchange.creator] >= paymentAmount, "Creator has insufficient balance");
            
            // Update balances
            userBalances[exchange.creator] = userBalances[exchange.creator].sub(paymentAmount);
            userBalances[msg.sender] = userBalances[msg.sender].add(paymentAmount);
        }
        
        // Update exchange participation
        exchangeParticipation[exchangeId][msg.sender] = exchangeParticipation[exchangeId][msg.sender].add(amount);
        userExchanges[msg.sender].add(exchangeId);
        
        // Check if exchange is now fulfilled
        if (exchangeParticipation[exchangeId][msg.sender] == exchange.amount) {
            exchange.isFulfilled = true;
            emit ExchangeFulfilled(exchangeId, msg.sender, block.timestamp);
        }
        
        emit ExchangeParticipated(exchangeId, msg.sender, amount);
    }
    
    // Cancel an exchange
    function cancelExchange(uint256 exchangeId) 
        external 
        whenNotPaused 
        validExchangeId(exchangeId) 
        nonReentrant 
        securityCheck 
    {
        Exchange storage exchange = exchanges[exchangeId];
        
        require(
            exchange.creator == msg.sender || owner() == msg.sender, 
            "Only creator or owner can cancel"
        );
        require(!exchange.isFulfilled, "Exchange already fulfilled");
        require(!exchange.isCancelled, "Exchange already cancelled");
        
        exchange.isCancelled = true;
        
        emit ExchangeCancelled(exchangeId, msg.sender, block.timestamp);
    }
    
    // Get user's exchanges
    function getUserExchanges(address user) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = userExchanges[user].length();
        uint256[] memory exchangeIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            exchangeIds[i] = userExchanges[user].at(i);
        }
        
        return exchangeIds;
    }
    
    // Get exchange participation for a user
    function getExchangeParticipation(uint256 exchangeId, address user) 
        external 
        view 
        returns (uint256) 
    {
        return exchangeParticipation[exchangeId][user];
    }
    
// END OF PART 2/12 - CONTINUE TO PART 3/12
// SPDX-License-Identifier: MIT
// PART 3/12 - MonadEcosystemHubV1
// Governance & Voting Functions
// Continues from PART 2/12

// CONTINUED FROM PART 2/12

    // ==================== GOVERNANCE & VOTING FUNCTIONS ====================
    
    // Create a new proposal
    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        bytes[] memory _actions,
        address[] memory _targets,
        uint256[] memory _values,
        string[] memory _signatures,
        ProposalParameters memory _parameters
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime <= _startTime + VOTING_PERIOD, "Voting period too long");
        require(_actions.length == _targets.length, "Actions and targets length mismatch");
        require(_targets.length == _values.length, "Targets and values length mismatch");
        require(_values.length == _signatures.length, "Values and signatures length mismatch");
        
        // Validate proposal parameters
        require(_parameters.quorum > 0, "Quorum must be greater than 0");
        require(_parameters.threshold > 0 && _parameters.threshold <= 100, "Threshold must be between 1 and 100");
        
        // Check if user has enough reputation to create a proposal
        require(userReputation[msg.sender] >= 100, "Insufficient reputation to create proposal");
        
        // Increment proposal ID counter
        _proposalIdCounter.increment();
        uint256 newProposalId = _proposalIdCounter.current();
        
        // Create new proposal
        Proposal storage newProposal = proposals[newProposalId];
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.proposer = msg.sender;
        newProposal.creationTime = block.timestamp;
        newProposal.startTime = _startTime;
        newProposal.endTime = _endTime;
        newProposal.executionTime = _endTime + EXECUTION_DELAY;
        newProposal.status = ProposalStatus.PENDING;
        newProposal.parameters = _parameters;
        
        // Store actions, targets, values, and signatures
        for (uint256 i = 0; i < _actions.length; i++) {
            newProposal.actions.push(_actions[i]);
            newProposal.targets.push(_targets[i]);
            newProposal.values.push(_values[i]);
            newProposal.signatures.push(_signatures[i]);
        }
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = 0.01 ether;
        require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        emit FeePaid(msg.sender, platformFeeAmount, "Proposal Creation");
        emit ProposalCreated(newProposalId, msg.sender, _title);
    }
    
    // Cast a vote on a proposal
    function castVote(uint256 proposalId, VoteType voteType, string memory reason) 
        external 
        whenNotPaused 
        validProposalId(proposalId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(votes[proposalId][msg.sender].timestamp == 0, "Already voted");
        
        // Calculate voting weight based on user reputation
        uint256 weight = userReputation[msg.sender];
        require(weight > 0, "No voting power");
        
        // Record vote
        Vote storage vote = votes[proposalId][msg.sender];
        vote.voteType = voteType;
        vote.weight = weight;
        vote.reason = reason;
        vote.timestamp = block.timestamp;
        
        // Update total votes
        if (voteType == VoteType.FOR) {
            proposal.forVotes = proposal.forVotes.add(weight);
        } else if (voteType == VoteType.AGAINST) {
            proposal.againstVotes = proposal.againstVotes.add(weight);
        } else if (voteType == VoteType.ABSTAIN) {
            proposal.abstainVotes = proposal.abstainVotes.add(weight);
        }
        
        // Add to user's voted proposals
        userVotedProposals[msg.sender].add(proposalId);
        
        emit VoteCast(proposalId, msg.sender, voteType, weight);
    }
    
    // Execute a successful proposal
    function executeProposal(uint256 proposalId) 
        external 
        whenNotPaused 
        validProposalId(proposalId) 
        nonReentrant 
        securityCheck 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            proposal.status == ProposalStatus.SUCCEEDED, 
            "Proposal not in succeeded state"
        );
        require(
            block.timestamp >= proposal.executionTime, 
            "Execution time not reached"
        );
        
        // Update proposal status
        proposal.status = ProposalStatus.EXECUTED;
        
        // Execute each action
        for (uint256 i = 0; i < proposal.actions.length; i++) {
            address target = proposal.targets[i];
            uint256 value = proposal.values[i];
            bytes memory data = proposal.actions[i];
            
            // Execute the call
            (bool success, ) = target.call{value: value}(data);
            require(success, "Proposal execution failed");
        }
        
        emit ProposalExecuted(proposalId, msg.sender, block.timestamp);
    }
    
    // Cancel a proposal (only proposer or contract owner)
    function cancelProposal(uint256 proposalId) 
        external 
        whenNotPaused 
        validProposalId(proposalId) 
        nonReentrant 
        securityCheck 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            proposal.proposer == msg.sender || owner() == msg.sender, 
            "Only proposer or owner can cancel"
        );
        require(
            proposal.status == ProposalStatus.PENDING || proposal.status == ProposalStatus.ACTIVE, 
            "Cannot cancel proposal in current state"
        );
        
        // Update proposal status
        proposal.status = ProposalStatus.CANCELED;
        
        emit ProposalCancelled(proposalId, msg.sender, block.timestamp);
    }
    
    // Process proposal state (update status based on votes)
    function processProposal(uint256 proposalId) 
        external 
        whenNotPaused 
        validProposalId(proposalId) 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        
        // Update proposal status based on current state
        if (proposal.status == ProposalStatus.PENDING && block.timestamp >= proposal.startTime) {
            proposal.status = ProposalStatus.ACTIVE;
        }
        
        if (proposal.status == ProposalStatus.ACTIVE && block.timestamp > proposal.endTime) {
            // Calculate total votes
            uint256 totalVotes = proposal.forVotes.add(proposal.againstVotes).add(proposal.abstainVotes);
            
            // Check if quorum is reached
            if (totalVotes >= proposal.parameters.quorum) {
                // Check if threshold is reached
                uint256 forPercentage = proposal.forVotes.mul(100).div(proposal.forVotes.add(proposal.againstVotes));
                
                if (forPercentage >= proposal.parameters.threshold) {
                    proposal.status = ProposalStatus.SUCCEEDED;
                } else {
                    proposal.status = ProposalStatus.DEFEATED;
                }
            } else {
                proposal.status = ProposalStatus.DEFEATED;
            }
        }
        
        // Check for expired proposals
        if (proposal.status == ProposalStatus.SUCCEEDED && 
            block.timestamp > proposal.executionTime + CLAIM_PERIOD) {
            proposal.status = ProposalStatus.EXPIRED;
        }
    }
    
    // Get proposal details
    function getProposalDetails(uint256 proposalId) 
        external 
        view 
        validProposalId(proposalId) 
        returns (
            string memory title,
            string memory description,
            address proposer,
            uint256 startTime,
            uint256 endTime,
            ProposalStatus status,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.status,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes
        );
    }
    
    // Get proposal actions
    function getProposalActions(uint256 proposalId) 
        external 
        view 
        validProposalId(proposalId) 
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        return (
            proposal.targets,
            proposal.values,
            proposal.signatures
        );
    }
    
    // Get vote details for a user on a proposal
    function getVoteDetails(uint256 proposalId, address voter) 
        external 
        view 
        validProposalId(proposalId) 
        returns (
            VoteType voteType,
            uint256 weight,
            string memory reason,
            uint256 timestamp
        ) 
    {
        Vote storage vote = votes[proposalId][voter];
        
        return (
            vote.voteType,
            vote.weight,
            vote.reason,
            vote.timestamp
        );
    }
    
    // Get proposals voted by a user
    function getUserVotedProposals(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = userVotedProposals[user].length();
        uint256[] memory proposalIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            proposalIds[i] = userVotedProposals[user].at(i);
        }
        
        return proposalIds;
    }
    
    // Batch process proposals
    function batchProcessProposals(uint256[] calldata proposalIds) 
        external 
        whenNotPaused 
        nonReentrant 
        withinBatchLimit(proposalIds.length)
    {
        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];
            
            if (proposalId > 0 && proposalId <= _proposalIdCounter.current()) {
                Proposal storage proposal = proposals[proposalId];
                
                // Update proposal status based on current state
                if (proposal.status == ProposalStatus.PENDING && block.timestamp >= proposal.startTime) {
                    proposal.status = ProposalStatus.ACTIVE;
                }
                
                if (proposal.status == ProposalStatus.ACTIVE && block.timestamp > proposal.endTime) {
                    // Calculate total votes
                    uint256 totalVotes = proposal.forVotes.add(proposal.againstVotes).add(proposal.abstainVotes);
                    
                    // Check if quorum is reached
                    if (totalVotes >= proposal.parameters.quorum) {
                        // Check if threshold is reached
                        uint256 forPercentage = proposal.forVotes.mul(100).div(
                            proposal.forVotes.add(proposal.againstVotes) > 0 ? 
                            proposal.forVotes.add(proposal.againstVotes) : 1
                        );
                        
                        if (forPercentage >= proposal.parameters.threshold) {
                            proposal.status = ProposalStatus.SUCCEEDED;
                        } else {
                            proposal.status = ProposalStatus.DEFEATED;
                        }
                    } else {
                        proposal.status = ProposalStatus.DEFEATED;
                    }
                }
                
                // Check for expired proposals
                if (proposal.status == ProposalStatus.SUCCEEDED && 
                    block.timestamp > proposal.executionTime + CLAIM_PERIOD) {
                    proposal.status = ProposalStatus.EXPIRED;
                }
            }
        }
    }
    
    // ==================== GAME FUNCTIONS ====================
    
    // Create a new game
    function createGame(
        string memory _name,
        string memory _description,
        GameType _gameType,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBet,
        uint256 _maxBet,
        GameParameters memory _parameters
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_minBet >= MIN_BET_AMOUNT, "Minimum bet too low");
        require(_maxBet <= MAX_BET_AMOUNT, "Maximum bet too high");
        require(_parameters.rakePercentage <= MAX_FEE, "Rake percentage too high");
        
        // Validate game parameters
        if (_parameters.maxPlayers > 0) {
            require(_parameters.maxPlayers <= 1000, "Max players too high");
        }
        
        // Increment game ID counter
        _gameIdCounter.increment();
        uint256 newGameId = _gameIdCounter.current();
        
        // Create new game
        Game storage newGame = games[newGameId];
        newGame.name = _name;
        newGame.description = _description;
        newGame.gameType = _gameType;
        newGame.creator = msg.sender;
        newGame.creationTime = block.timestamp;
        newGame.startTime = _startTime;
        newGame.endTime = _endTime;
        newGame.isActive = true;
        newGame.minBet = _minBet;
        newGame.maxBet = _maxBet;
        newGame.parameters = _parameters;
        
        // Add to user's games
        userGames[msg.sender].add(newGameId);
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = 0.01 ether;
        require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        emit FeePaid(msg.sender, platformFeeAmount, "Game Creation");
        emit GameCreated(newGameId, msg.sender, _name);
    }
    
    // Place a bet on a game
    function placeBet(uint256 gameId) 
        external 
        payable 
        whenNotPaused 
        validGameId(gameId) 
        activeGame(gameId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Game storage game = games[gameId];
        
        require(block.timestamp >= game.startTime, "Game not started");
        require(block.timestamp <= game.endTime, "Game ended");
        require(msg.value >= game.minBet, "Bet amount below minimum");
        require(msg.value <= game.maxBet, "Bet amount above maximum");
        
        // Check if maximum players reached
        if (game.parameters.maxPlayers > 0) {
            require(
                game.totalPool.div(game.minBet) < game.parameters.maxPlayers, 
                "Maximum players reached"
            );
        }
        
        // Check if rebuy is allowed
        if (!game.parameters.allowRebuy) {
            require(gameBets[gameId][msg.sender] == 0, "Multiple bets not allowed");
        }
        
        // Add bet to game
        gameBets[gameId][msg.sender] = gameBets[gameId][msg.sender].add(msg.value);
        game.totalPool = game.totalPool.add(msg.value);
        
        // Add to user's games
        userGames[msg.sender].add(gameId);
        
        emit BetPlaced(gameId, msg.sender, msg.value);
    }
    
    // End game and determine winners (can only be called by game creator or contract owner)
    function endGame(uint256 gameId, address[] calldata winners, uint256[] calldata rewardAmounts) 
        external 
        whenNotPaused 
        validGameId(gameId) 
        activeGame(gameId) 
        nonReentrant 
        securityCheck 
    {
        Game storage game = games[gameId];
        
        require(
            game.creator == msg.sender || owner() == msg.sender, 
            "Only creator or owner can end game"
        );
        require(
            block.timestamp >= game.startTime, 
            "Game not started"
        );
        require(winners.length == rewardAmounts.length, "Winners and rewards length mismatch");
        
        // Calculate total rewards
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < rewardAmounts.length; i++) {
            totalRewards = totalRewards.add(rewardAmounts[i]);
        }
        
        // Calculate rake amount
        uint256 rakeAmount = (game.totalPool.mul(game.parameters.rakePercentage)).div(FEE_DENOMINATOR);
        
        // Ensure total rewards plus rake doesn't exceed total pool
        require(totalRewards.add(rakeAmount) <= game.totalPool, "Rewards exceed available pool");
        
        // Update game state
        game.isActive = false;
        game.winners = winners;
        game.rewards = rewardAmounts;
        
        // Transfer rake to fee collector
        if (rakeAmount > 0) {
            userBalances[feeCollector] = userBalances[feeCollector].add(rakeAmount);
            emit FeePaid(address(this), rakeAmount, "Game Rake");
        }
        
        // Transfer rewards to winners
        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            uint256 rewardAmount = rewardAmounts[i];
            
            if (rewardAmount > 0) {
                userBalances[winner] = userBalances[winner].add(rewardAmount);
                
                // Update winner's reputation
                userReputation[winner] = userReputation[winner].add(10);
            }
        }
        
        // If there's any remaining pool, transfer it to the creator
        uint256 remainingPool = game.totalPool.sub(totalRewards).sub(rakeAmount);
        if (remainingPool > 0) {
            userBalances[game.creator] = userBalances[game.creator].add(remainingPool);
        }
        
        emit GameEnded(gameId, block.timestamp, winners);
    }
    
    // Get game details
    function getGameDetails(uint256 gameId) 
        external 
        view 
        validGameId(gameId) 
        returns (
            string memory name,
            string memory description,
            GameType gameType,
            address creator,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            uint256 totalPool,
            uint256 minBet,
            uint256 maxBet
        ) 
    {
        Game storage game = games[gameId];
        
        return (
            game.name,
            game.description,
            game.gameType,
            game.creator,
            game.startTime,
            game.endTime,
            game.isActive,
            game.totalPool,
            game.minBet,
            game.maxBet
        );
    }
    
    // Get user's bet on a game
    function getUserBet(uint256 gameId, address user) 
        external 
        view 
        validGameId(gameId) 
        returns (uint256) 
    {
        return gameBets[gameId][user];
    }
    
    // Get games played by a user
    function getUserGames(address user) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = userGames[user].length();
        uint256[] memory gameIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            gameIds[i] = userGames[user].at(i);
        }
        
        return gameIds;
    }
    
    // Get game winners and rewards
    function getGameWinnersAndRewards(uint256 gameId) 
        external 
        view 
        validGameId(gameId) 
        returns (
            address[] memory winners,
            uint256[] memory rewardAmounts
        ) 
    {
        Game storage game = games[gameId];
        
        return (
            game.winners,
            game.rewards
        );
    }
    
// END OF PART 3/12 - CONTINUE TO PART 4/12
// SPDX-License-Identifier: MIT
// PART 4/12 - MonadEcosystemHubV1
// Data & Analytics Functions
// Continues from PART 3/12

// CONTINUED FROM PART 3/12

    // ==================== DATA & ANALYTICS FUNCTIONS ====================
    
    // Create a new dataset
    // --- วางฟังก์ชันนี้แทนที่ createDataset อันเดิม ---
function createDataset(
       string memory _name,
       string memory _description,
       DatasetType _datasetType,
       bool _isPublic,
       uint256 _accessPrice,
       string[] memory _tags, // ยังคงรับเข้ามา
       string memory _contentURI,
       // --- Pass DatasetParameters fields individually ---
       uint256 _paramSize,
       string memory _paramFormat,
       uint256 _paramVersion,
       string memory _paramLicense,
       string[] memory _paramContributors, // ยังคงรับเข้ามา
       uint256 _paramUpdateFrequency,
       bool _paramIsVerified
   )
       external
       whenNotPaused
       onlyRegistered
       nonReentrant
       securityCheck
       withinBatchLimit(_tags.length)
       withinBatchLimit(_paramContributors.length)
   {
       // --- ส่วน Requires (ใช้ stack น้อย) ---
       require(bytes(_name).length > 0, "Name cannot be empty");
       require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
       require(bytes(_contentURI).length <= MAX_URI_LENGTH, "Content URI too long");

       // --- ส่วนหลัก ---
       _datasetIdCounter.increment();
       uint256 newDatasetId = _datasetIdCounter.current(); // ตัวแปร local 1

       // ชี้ไปยัง storage (ใช้ stack น้อย)
       Dataset storage newDataset = datasets[newDatasetId];

       // กำหนดค่าพื้นฐาน (ใช้ stack น้อย)
       newDataset.name = _name;
       newDataset.description = _description;
       newDataset.datasetType = _datasetType;
       newDataset.owner = msg.sender;
       newDataset.creationTime = block.timestamp;
       newDataset.updateTime = block.timestamp; // กำหนด updateTime ที่นี่เลย
       newDataset.isPublic = _isPublic;
       newDataset.accessPrice = _accessPrice;
       newDataset.contentURI = _contentURI;

       // --- เรียกใช้ฟังก์ชัน Internal ย่อยๆ ---
       // ลดการใช้ stack สำหรับ parameters/struct
       _setDatasetParameters(
           newDataset,
           _paramSize, _paramFormat, _paramVersion, _paramLicense,
           _paramContributors, _paramUpdateFrequency, _paramIsVerified
       );

       // ลดการใช้ stack สำหรับ loop tags
       _processDatasetTags(newDataset, _tags);

       // ลดการใช้ stack สำหรับ fee/storage updates
       _finalizeDatasetCreation(newDatasetId);

       // Emit event สุดท้าย (stack น่าจะพอแล้ว)
       emit DatasetCreated(newDatasetId, msg.sender, _name);
   }
    
    // Update dataset details
    function updateDataset(
        uint256 datasetId,
        string memory _name,
        string memory _description,
        bool _isPublic,
        uint256 _accessPrice,
        string memory _contentURI
    ) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
    {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(bytes(_contentURI).length <= MAX_URI_LENGTH, "Content URI too long");
        
        Dataset storage dataset = datasets[datasetId];
        dataset.name = _name;
        dataset.description = _description;
        dataset.isPublic = _isPublic;
        dataset.accessPrice = _accessPrice;
        dataset.contentURI = _contentURI;
        dataset.updateTime = block.timestamp;
        
        emit DatasetUpdated(datasetId, msg.sender, block.timestamp);
    }
    
    // Update dataset parameters
    function updateDatasetParameters(
        uint256 datasetId,
        DatasetParameters memory _parameters
    ) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
    {
        Dataset storage dataset = datasets[datasetId];
        dataset.parameters = _parameters;
        dataset.updateTime = block.timestamp;
        
        emit DatasetUpdated(datasetId, msg.sender, block.timestamp);
    }
    
    // Update dataset tags
    function updateDatasetTags(
        uint256 datasetId,
        string[] memory _tags
    ) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
        withinBatchLimit(_tags.length)
    {
        Dataset storage dataset = datasets[datasetId];
        
        // Clear existing tags
        delete dataset.tags;
        
        // Add new tags
        for (uint256 i = 0; i < _tags.length; i++) {
            dataset.tags.push(_tags[i]);
        }
        
        dataset.updateTime = block.timestamp;
        
        emit DatasetUpdated(datasetId, msg.sender, block.timestamp);
    }
    
    // Grant access to a dataset
    function grantDatasetAccess(uint256 datasetId, address user) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
    {
        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");
        
        datasetAccess[datasetId][user] = true;
        
        emit DatasetAccessed(datasetId, user, block.timestamp);
    }
    
    // Revoke access to a dataset
    function revokeDatasetAccess(uint256 datasetId, address user) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
    {
        require(user != address(0), "Invalid user address");
        require(user != datasets[datasetId].owner, "Cannot revoke owner's access");
        
        datasetAccess[datasetId][user] = false;
    }
    
    // Batch grant access to a dataset
    function batchGrantDatasetAccess(uint256 datasetId, address[] calldata users) 
        external 
        whenNotPaused 
        onlyDatasetOwner(datasetId) 
        validDatasetId(datasetId) 
        nonReentrant 
        securityCheck 
        withinBatchLimit(users.length)
    {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            require(user != address(0), "Invalid user address");
            require(isRegistered[user], "User not registered");
            
            datasetAccess[datasetId][user] = true;
            
            emit DatasetAccessed(datasetId, user, block.timestamp);
        }
    }
    
    // Purchase access to a dataset
    function purchaseDatasetAccess(uint256 datasetId) 
        external 
        payable 
        whenNotPaused 
        validDatasetId(datasetId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Dataset storage dataset = datasets[datasetId];
        
        require(!datasetAccess[datasetId][msg.sender], "Already have access");
        
        if (dataset.isPublic) {
            // If dataset is public, it may still have an access price
            if (dataset.accessPrice > 0) {
                require(msg.value >= dataset.accessPrice, "Insufficient payment");
                
                // Calculate platform fee
                uint256 platformFeeAmount = (dataset.accessPrice.mul(platformFee)).div(FEE_DENOMINATOR);
                uint256 ownerAmount = dataset.accessPrice.sub(platformFeeAmount);
                
                // Update balances
                userBalances[dataset.owner] = userBalances[dataset.owner].add(ownerAmount);
                userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
                
                // Refund excess payment
                if (msg.value > dataset.accessPrice) {
                    (bool success, ) = msg.sender.call{value: msg.value - dataset.accessPrice}("");
                    require(success, "Refund failed");
                }
                
                emit FeePaid(msg.sender, platformFeeAmount, "Dataset Access");
            }
            
            // Grant access
            datasetAccess[datasetId][msg.sender] = true;
            
            emit DatasetAccessed(datasetId, msg.sender, block.timestamp);
        } else {
            revert("Dataset is not public");
        }
    }
    
    // Contribute to a dataset
    function contributeToDataset(
        uint256 datasetId,
        string memory contributionURI,
        string memory contributionDescription
    ) 
        external 
        whenNotPaused 
        validDatasetId(datasetId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Dataset storage dataset = datasets[datasetId];
        
        require(
            datasetAccess[datasetId][msg.sender] || msg.sender == dataset.owner,
            "No access to dataset"
        );
        require(bytes(contributionURI).length <= MAX_URI_LENGTH, "Contribution URI too long");
        
        // Add contributor to the list if not already there
        bool isContributor = false;
        for (uint256 i = 0; i < dataset.parameters.contributors.length; i++) {
            if (keccak256(bytes(dataset.parameters.contributors[i])) == keccak256(bytes(userProfiles[msg.sender].name))) {
                isContributor = true;
                break;
            }
        }
        
        if (!isContributor) {
            dataset.parameters.contributors.push(userProfiles[msg.sender].name);
        }
        
        // Update dataset
        dataset.updateTime = block.timestamp;
        
        // Increase contributor's reputation
        userReputation[msg.sender] = userReputation[msg.sender].add(5);
        
        emit DataContribution(datasetId, msg.sender, block.timestamp);
    }
    
    // Check if user has access to a dataset
    function hasDatasetAccess(uint256 datasetId, address user) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (bool) 
    {
        return datasetAccess[datasetId][user] || datasets[datasetId].owner == user;
    }
    
    // Get dataset details
    function getDatasetDetails(uint256 datasetId) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (
            string memory name,
            string memory description,
            DatasetType datasetType,
            address owner,
            uint256 creationTime,
            uint256 updateTime,
            bool isPublic,
            uint256 accessPrice,
            string memory contentURI
        ) 
    {
        Dataset storage dataset = datasets[datasetId];
        
        return (
            dataset.name,
            dataset.description,
            dataset.datasetType,
            dataset.owner,
            dataset.creationTime,
            dataset.updateTime,
            dataset.isPublic,
            dataset.accessPrice,
            dataset.contentURI
        );
    }
    
    // Get dataset tags
    function getDatasetTags(uint256 datasetId) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (string[] memory) 
    {
        return datasets[datasetId].tags;
    }
    
    // Get dataset parameters
    function getDatasetParameters(uint256 datasetId) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (DatasetParameters memory) 
    {
        return datasets[datasetId].parameters;
    }
    
    // Get datasets owned by a user
    function getUserOwnedDatasets(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = ownedDatasets[user].length();
        uint256[] memory datasetIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            datasetIds[i] = ownedDatasets[user].at(i);
        }
        
        return datasetIds;
    }
    
    // Get datasets by type
    function getDatasetsByType(DatasetType datasetType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count datasets of the specified type
        for (uint256 i = 1; i <= _datasetIdCounter.current(); i++) {
            if (datasets[i].datasetType == datasetType) {
                count++;
            }
        }
        
        // Create array to hold matching dataset IDs
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill the array
        for (uint256 i = 1; i <= _datasetIdCounter.current(); i++) {
            if (datasets[i].datasetType == datasetType) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Data aggregation function - get total users count
    function getTotalUsersCount() 
        public 
        view 
        returns (uint256) 
    {
        uint256 count = 0;
        
        for (uint256 i = 0; i < 1000; i++) {
            address account = address(uint160(i + 1));
            if (isRegistered[account]) {
                count++;
            }
            if (count >= 1000) break; // Limit to prevent gas issues
        }
        
        return count;
    }
    
    // Data aggregation function - get total resources count
    function getTotalResourcesCount() 
        external 
        view 
        returns (uint256) 
    {
        return _resourceIdCounter.current();
    }
    
    // Data aggregation function - get total exchanges count
    function getTotalExchangesCount() 
        external 
        view 
        returns (uint256) 
    {
        return _exchangeIdCounter.current();
    }
    
    // Data aggregation function - get total proposals count
    function getTotalProposalsCount() 
        external 
        view 
        returns (uint256) 
    {
        return _proposalIdCounter.current();
    }
    
    // Data aggregation function - get total games count
    function getTotalGamesCount() 
        external 
        view 
        returns (uint256) 
    {
        return _gameIdCounter.current();
    }
    
    // Data aggregation function - get total datasets count
    function getTotalDatasetsCount() 
        external 
        view 
        returns (uint256) 
    {
        return _datasetIdCounter.current();
    }
    
    // Data analytics function - get resource allocation statistics
    function getResourceAllocationStats(uint256 resourceId) 
        external 
        view 
        validResourceId(resourceId) 
        returns (
            uint256 totalAllocated,
            uint256 totalUsers,
            uint256 availableSupply
        ) 
    {
        uint256 allocated = 0;
        uint256 users = 0;
        
        // Loop through a limited number of addresses to prevent gas issues
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            uint256 userAllocation = resourceAllocation[resourceId][user];
            
            if (userAllocation > 0) {
                allocated = allocated.add(userAllocation);
                users++;
            }
            
            if (users >= 1000) break; // Limit to prevent gas issues
        }
        
        return (
            allocated,
            users,
            resources[resourceId].availableSupply
        );
    }
    
    // Data analytics function - get exchange participation statistics
    function getExchangeParticipationStats(uint256 exchangeId) 
        external 
        view 
        validExchangeId(exchangeId) 
        returns (
            uint256 totalParticipation,
            uint256 totalParticipants
        ) 
    {
        uint256 participation = 0;
        uint256 participants = 0;
        
        // Loop through a limited number of addresses to prevent gas issues
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            uint256 userParticipation = exchangeParticipation[exchangeId][user];
            
            if (userParticipation > 0) {
                participation = participation.add(userParticipation);
                participants++;
            }
            
            if (participants >= 1000) break; // Limit to prevent gas issues
        }
        
        return (
            participation,
            participants
        );
    }
    
    // Data analytics function - get proposal voting statistics
    function getProposalVotingStats(uint256 proposalId) 
        external 
        view 
        validProposalId(proposalId) 
        returns (
            uint256 totalVotes,
            uint256 totalVoters,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 voters = 0;
        
        // Loop through a limited number of addresses to prevent gas issues
        for (uint256 i = 0; i < 1000; i++) {
            address voter = address(uint160(i + 1));
            Vote storage vote = votes[proposalId][voter];
            
            if (vote.timestamp > 0) {
                voters++;
            }
            
            if (voters >= 1000) break; // Limit to prevent gas issues
        }
        
        return (
            proposal.forVotes.add(proposal.againstVotes).add(proposal.abstainVotes),
            voters,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes
        );
    }
    
    // Data analytics function - get game participation statistics
    function getGameParticipationStats(uint256 gameId) 
        external 
        view 
        validGameId(gameId) 
        returns (
            uint256 totalBets,
            uint256 totalPlayers,
            uint256 averageBet
        ) 
    {
        Game storage game = games[gameId];
        uint256 players = 0;
        
        // Loop through a limited number of addresses to prevent gas issues
        for (uint256 i = 0; i < 1000; i++) {
            address player = address(uint160(i + 1));
            uint256 playerBet = gameBets[gameId][player];
            
            if (playerBet > 0) {
                players++;
            }
            
            if (players >= 1000) break; // Limit to prevent gas issues
        }
        
        // Calculate average bet
        uint256 avgBet = 0;
        if (players > 0) {
            avgBet = game.totalPool.div(players);
        }
        
        return (
            game.totalPool,
            players,
            avgBet
        );
    }
    
    // Data analytics function - get dataset access statistics
    function getDatasetAccessStats(uint256 datasetId) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (
            uint256 totalAccessUsers,
            uint256 totalContributors
        ) 
    {
        Dataset storage dataset = datasets[datasetId];
        uint256 accessUsers = 0;
        
        // Loop through a limited number of addresses to prevent gas issues
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (datasetAccess[datasetId][user]) {
                accessUsers++;
            }
            
            if (accessUsers >= 1000) break; // Limit to prevent gas issues
        }
        
        return (
            accessUsers,
            dataset.parameters.contributors.length
        );
    }
    
    // Data analysis function - calculate user activity score
    function calculateUserActivityScore(address user) 
        public 
        view 
        returns (uint256) 
    {
        if (!isRegistered[user]) {
            return 0;
        }
        
        uint256 score = 0;
        
        // Resources owned
        score = score.add(ownedResources[user].length().mul(10));
        
        // Exchanges participated
        score = score.add(userExchanges[user].length().mul(5));
        
        // Proposals voted
        score = score.add(userVotedProposals[user].length().mul(20));
        
        // Games played
        score = score.add(userGames[user].length().mul(5));
        
        // Datasets owned
        score = score.add(ownedDatasets[user].length().mul(15));
        
        // Reputation
        score = score.add(userReputation[user]);
        
        // Last activity bonus (more recent = more points)
        uint256 lastActivity = userProfiles[user].lastActivityTime;
        if (lastActivity > 0) {
            uint256 daysSinceLastActivity = (block.timestamp - lastActivity) / 1 days;
            
            if (daysSinceLastActivity < 30) {
                score = score.add(30 - daysSinceLastActivity);
            }
        }
        
        return score;
    }
    
    // Data analysis function - get top resources by allocation
    function getTopResourcesByAllocation(uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 totalResources = _resourceIdCounter.current();
        uint256 resultSize = limit < totalResources ? limit : totalResources;
        
        // Create arrays to store resource IDs and their allocation counts
        uint256[] memory resourceIds = new uint256[](totalResources);
        uint256[] memory allocationCounts = new uint256[](totalResources);
        
        // Populate the arrays
        for (uint256 i = 0; i < totalResources; i++) {
            uint256 resourceId = i + 1;
            resourceIds[i] = resourceId;
            
            // Calculate total allocation for this resource (simplified)
            uint256 allocated = 0;
            for (uint256 j = 0; j < 100; j++) { // Sample 100 addresses
                address user = address(uint160(j + 1));
                allocated = allocated.add(resourceAllocation[resourceId][user]);
            }
            
            allocationCounts[i] = allocated;
        }
        
        // Sort the arrays by allocation count (bubble sort for simplicity)
        for (uint256 i = 0; i < totalResources; i++) {
            for (uint256 j = 0; j < totalResources - i - 1; j++) {
                if (allocationCounts[j] < allocationCounts[j + 1]) {
                    // Swap allocation counts
                    uint256 tempCount = allocationCounts[j];
                    allocationCounts[j] = allocationCounts[j + 1];
                    allocationCounts[j + 1] = tempCount;
                    
                    // Swap resource IDs
                    uint256 tempId = resourceIds[j];
                    resourceIds[j] = resourceIds[j + 1];
                    resourceIds[j + 1] = tempId;
                }
            }
        }
        
        // Create result array with the top resources
        uint256[] memory result = new uint256[](resultSize);
        for (uint256 i = 0; i < resultSize; i++) {
            result[i] = resourceIds[i];
        }
        
        return result;
    }
    
    // Data analysis function - get top datasets by access count
    function getTopDatasetsByAccessCount(uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 totalDatasets = _datasetIdCounter.current();
        uint256 resultSize = limit < totalDatasets ? limit : totalDatasets;
        
        // Create arrays to store dataset IDs and their access counts
        uint256[] memory datasetIds = new uint256[](totalDatasets);
        uint256[] memory accessCounts = new uint256[](totalDatasets);
        
        // Populate the arrays
        for (uint256 i = 0; i < totalDatasets; i++) {
            uint256 datasetId = i + 1;
            datasetIds[i] = datasetId;
            
            // Calculate access count for this dataset (simplified)
            uint256 accessCount = 0;
            for (uint256 j = 0; j < 100; j++) { // Sample 100 addresses
                address user = address(uint160(j + 1));
                if (datasetAccess[datasetId][user]) {
                    accessCount++;
                }
            }
            
            accessCounts[i] = accessCount;
        }
        
        // Sort the arrays by access count (bubble sort for simplicity)
        for (uint256 i = 0; i < totalDatasets; i++) {
            for (uint256 j = 0; j < totalDatasets - i - 1; j++) {
                if (accessCounts[j] < accessCounts[j + 1]) {
                    // Swap access counts
                    uint256 tempCount = accessCounts[j];
                    accessCounts[j] = accessCounts[j + 1];
                    accessCounts[j + 1] = tempCount;
                    
                    // Swap dataset IDs
                    uint256 tempId = datasetIds[j];
                    datasetIds[j] = datasetIds[j + 1];
                    datasetIds[j + 1] = tempId;
                }
            }
        }
        
        // Create result array with the top datasets
        uint256[] memory result = new uint256[](resultSize);
        for (uint256 i = 0; i < resultSize; i++) {
            result[i] = datasetIds[i];
        }
        
        return result;
    }
    
// END OF PART 4/12 - CONTINUE TO PART 5/12
// SPDX-License-Identifier: MIT
// PART 5/12 - MonadEcosystemHubV1
// Security & Utility Functions
// Continues from PART 4/12

// CONTINUED FROM PART 4/12

    // ==================== SECURITY FUNCTIONS ====================
    
    // Check if an operation has been executed
   
    
    // Set operation as executed
    function setOperationExecuted(bytes32 operationHash) 
        external 
        onlyOwner 
    {
        isOperationExecuted[operationHash] = true;
        operationTimestamps[operationHash] = block.timestamp;
    }
    
    // Check if user action count is within limits
    function checkUserActionLimit(address user) 
        external 
        view 
        returns (bool) 
    {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lastActionDay = lastActionTimestamp[user] / 1 days;
        
        if (currentDay > lastActionDay) {
            return true; // New day, reset count
        }
        
        // Define a reasonable daily action limit
        uint256 dailyActionLimit = 100;
        
        return actionCount[user] < dailyActionLimit;
    }
    
    // Create a security operation hash
    function createOperationHash(
        address target,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) 
        public 
        pure 
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(target, value, keccak256(data), nonce));
    }
    
    // Verify a signature for an operation
    function verifySignature(
        bytes32 operationHash,
        bytes memory signature,
        address signer
    ) 
        public 
        pure 
        returns (bool) 
    {
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", operationHash)
        );
        
        return ethSignedMessageHash.recover(signature) == signer;
    }
    
    // Execute a timelocked operation
    function executeTimelocked(
        address target,
        uint256 value,
        bytes memory data,
        uint256 timelock
    ) 
        external 
        onlyOwner 
        nonReentrant 
    {
        bytes32 operationHash = createOperationHash(target, value, data, block.timestamp);
        
        // Check if operation is already scheduled
        if (operationTimestamps[operationHash] == 0) {
            // Schedule operation
            operationTimestamps[operationHash] = block.timestamp;
            return;
        }
        
        // Check if timelock has expired
        require(
            block.timestamp >= operationTimestamps[operationHash] + timelock,
            "Timelock not expired"
        );
        
        // Check if operation was already executed
        require(!isOperationExecuted[operationHash], "Operation already executed");
        
        // Mark as executed
        isOperationExecuted[operationHash] = true;
        
        // Execute operation
        (bool success, ) = target.call{value: value}(data);
        require(success, "Operation execution failed");
    }
    
    // Add address to security blacklist
    function addToBlacklist(address account) 
        external 
        onlyOwner 
    {
        isWhitelisted[account] = false;
        emit WhitelistUpdated(account, false);
        emit SecurityBreach(account, "Added to blacklist", block.timestamp);
    }
    
    // Report a security breach
    function reportSecurityBreach(address account, string memory breachType) 
        external 
        onlyOwner 
    {
        emit SecurityBreach(account, breachType, block.timestamp);
    }
    
    // Set up security configuration for the contract
    function setSecurityConfig(SecurityConfig memory config) 
        external 
        onlyOwner 
    {
        // This would update a global security configuration
        // For simplicity, we'll emit an event to record the change
        emit SecurityBreach(address(0), "Security config updated", block.timestamp);
    }
    
    // Emergency withdrawal of all funds by owner
    function emergencyWithdraw() 
        external 
        onlyOwner 
    {
        require(emergencyMode, "Not in emergency mode");
        
        // Get contract balance
        uint256 balance = address(this).balance;
        
        // Send all funds to owner
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
        
        emit EmergencyModeDeactivated(msg.sender, block.timestamp);
        emergencyMode = false;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    // Get the current timestamp
    function getBlockTimestamp() 
        external 
        view 
        returns (uint256) 
    {
        return block.timestamp;
    }
    
    // Get the current block number
    function getBlockNumber() 
        external 
        view 
        returns (uint256) 
    {
        return block.number;
    }
    
    // Get contract metadata
    function getContractMetadata() 
        external 
        view 
        returns (
            string memory contractName,
            string memory contractSymbol,
            string memory contractVersion,
            address contractOwner,
            uint256 platformFeePercentage,
            address feeCollectorAddress,
            bool isEmergencyModeActive
        ) 
    {
        return (
            name,
            symbol,
            VERSION,
            owner(),
            platformFee,
            feeCollector,
            emergencyMode
        );
    }
    
    // Get contract statistics
    function getContractStatistics() 
        external 
        view 
        returns (
            uint256 totalResources,
            uint256 totalExchanges,
            uint256 totalProposals,
            uint256 totalGames,
            uint256 totalDatasets,
            uint256 contractBalance
        ) 
    {
        return (
            _resourceIdCounter.current(),
            _exchangeIdCounter.current(),
            _proposalIdCounter.current(),
            _gameIdCounter.current(),
            _datasetIdCounter.current(),
            address(this).balance
        );
    }
    
    // Generate a random number (not truly random, for demonstration purposes only)
    function generateRandomNumber(uint256 seed, uint256 max) 
        public 
        view 
        returns (uint256) 
    {
        require(max > 0, "Max value must be greater than 0");
        
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    msg.sender,
                    seed
                )
            )
        ) % max;
    }
    
    // Calculate fee amount based on value and fee percentage
    function calculateFee(uint256 value) 
        public 
        view 
        returns (uint256) 
    {
        return (value.mul(platformFee)).div(FEE_DENOMINATOR);
    }
    
    // Generate token ID for a new resource
    function generateResourceTokenId(address creator, string memory name) 
        public 
        pure 
        returns (uint256) 
    {
        return uint256(keccak256(abi.encodePacked(creator, name)));
    }
    
    // Check if a string is empty
    function isStringEmpty(string memory str) 
        public 
        pure 
        returns (bool) 
    {
        return bytes(str).length == 0;
    }
    
    // Compare two strings
    function compareStrings(string memory a, string memory b) 
        public 
        pure 
        returns (bool) 
    {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
    
    // Get the contract address
    function getContractAddress() 
        external 
        view 
        returns (address) 
    {
        return address(this);
    }
    
    // ==================== METADATA FUNCTIONS ====================
    
    // Get the URI for a resource
    function getResourceURI(uint256 resourceId) 
        external 
        view 
        validResourceId(resourceId) 
        returns (string memory) 
    {
        return string(abi.encodePacked(baseURI, "resource/", resourceId.toString()));
    }
    
    // Get the URI for a game
    function getGameURI(uint256 gameId) 
        external 
        view 
        validGameId(gameId) 
        returns (string memory) 
    {
        return string(abi.encodePacked(baseURI, "game/", gameId.toString()));
    }
    
    // Get the URI for a proposal
    function getProposalURI(uint256 proposalId) 
        external 
        view 
        validProposalId(proposalId) 
        returns (string memory) 
    {
        return string(abi.encodePacked(baseURI, "proposal/", proposalId.toString()));
    }
    
    // Get the URI for a dataset
    function getDatasetURI(uint256 datasetId) 
        external 
        view 
        validDatasetId(datasetId) 
        returns (string memory) 
    {
        return string(abi.encodePacked(baseURI, "dataset/", datasetId.toString()));
    }
    
    // Get the URI for a user profile
    function getUserProfileURI(address user) 
        external 
        view 
        returns (string memory) 
    {
        require(isRegistered[user], "User not registered");
        
        return string(abi.encodePacked(baseURI, "user/", Strings.toHexString(uint160(user))));
    }
    
    // ==================== RESOURCE MANAGEMENT EXTENDED FUNCTIONS ====================
    
    // Activate multiple resources
    function batchActivateResources(uint256[] calldata resourceIds) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
        withinBatchLimit(resourceIds.length)
    {
        for (uint256 i = 0; i < resourceIds.length; i++) {
            uint256 resourceId = resourceIds[i];
            
            require(resourceId > 0 && resourceId <= _resourceIdCounter.current(), "Invalid resource ID");
            require(resources[resourceId].owner == msg.sender, "Not the resource owner");
            
            resources[resourceId].isActive = true;
            resources[resourceId].updateTime = block.timestamp;
            
            emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
        }
    }
    
    // Deactivate multiple resources
    function batchDeactivateResources(uint256[] calldata resourceIds) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
        withinBatchLimit(resourceIds.length)
    {
        for (uint256 i = 0; i < resourceIds.length; i++) {
            uint256 resourceId = resourceIds[i];
            
            require(resourceId > 0 && resourceId <= _resourceIdCounter.current(), "Invalid resource ID");
            require(resources[resourceId].owner == msg.sender, "Not the resource owner");
            
            resources[resourceId].isActive = false;
            resources[resourceId].updateTime = block.timestamp;
            
            emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
        }
    }
    
    // Update resource supply
    function updateResourceSupply(uint256 resourceId, uint256 newTotalSupply) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        nonReentrant 
        securityCheck 
    {
        Resource storage resource = resources[resourceId];
        
        // Calculate how much supply has been allocated
        uint256 allocatedSupply = resource.totalSupply.sub(resource.availableSupply);
        
        // New total supply must be at least equal to already allocated supply
        require(newTotalSupply >= allocatedSupply, "New supply too low");
        
        // Update supply
        resource.totalSupply = newTotalSupply;
        resource.availableSupply = newTotalSupply.sub(allocatedSupply);
        resource.updateTime = block.timestamp;
        
        emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
    }
    
    // Get resources by type
    function getResourcesByType(ResourceType resourceType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count resources of the specified type
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            if (resources[i].resourceType == resourceType) {
                count++;
            }
        }
        
        // Create array to hold matching resource IDs
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill the array
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            if (resources[i].resourceType == resourceType) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Search resources by name
    function searchResourcesByName(string memory searchTerm) 
        external 
        view 
        returns (uint256[] memory) 
    {
        // For simplicity, we'll limit search results to a maximum of 100
        uint256[] memory result = new uint256[](100);
        uint256 resultCount = 0;
        
        for (uint256 i = 1; i <= _resourceIdCounter.current() && resultCount < 100; i++) {
            // Basic string search (case sensitive)
            // In a real implementation, you might want a more sophisticated search algorithm
            if (
                bytes(searchTerm).length > 0 && 
                containsSubstring(resources[i].name, searchTerm)
            ) {
                result[resultCount] = i;
                resultCount++;
            }
        }
        
        // Create properly sized result array
        uint256[] memory trimmedResult = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            trimmedResult[i] = result[i];
        }
        
        return trimmedResult;
    }
    
    // Check if a string contains a substring (helper function)
    function containsSubstring(string memory str, string memory substr) 
        internal 
        pure 
        returns (bool) 
    {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length == 0) {
            return true;
        }
        if (strBytes.length < substrBytes.length) {
            return false;
        }
        
        // Simple string search algorithm
        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        
        return false;
    }
    
    // ==================== EXCHANGE EXTENDED FUNCTIONS ====================
    
    // Batch create exchanges
    function batchCreateExchanges(
        string[] memory names,
        string[] memory descriptions,
        ExchangeType[] memory exchangeTypes,
        address[] memory tokenAddresses,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256[] memory prices,
        ExchangeConditions[] memory conditions
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(names.length)
    {
        require(
            names.length == descriptions.length &&
            descriptions.length == exchangeTypes.length &&
            exchangeTypes.length == tokenAddresses.length &&
            tokenAddresses.length == tokenIds.length &&
            tokenIds.length == amounts.length &&
            amounts.length == prices.length &&
            prices.length == conditions.length,
            "Array length mismatch"
        );
        
        // Calculate total platform fee
        uint256 totalPlatformFee = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            totalPlatformFee = totalPlatformFee.add((prices[i].mul(platformFee)).div(FEE_DENOMINATOR));
        }
        
        require(userBalances[msg.sender] >= totalPlatformFee, "Insufficient balance for platform fees");
        
        // Create exchanges
        for (uint256 i = 0; i < names.length; i++) {
            require(bytes(names[i]).length > 0, "Name cannot be empty");
            require(bytes(descriptions[i]).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
            require(amounts[i] > 0, "Amount must be greater than 0");
            
            // Validate exchange conditions
            if (conditions[i].deadline > 0) {
                require(conditions[i].deadline > block.timestamp, "Deadline must be in the future");
            }
            
            // For token exchanges, validate token ownership and approval
            if (tokenAddresses[i] != address(0)) {
                if (exchangeTypes[i] == ExchangeType.SELL || exchangeTypes[i] == ExchangeType.SWAP) {
                    // For ERC20 tokens
                    if (tokenIds[i] == 0) {
                        IERC20 token = IERC20(tokenAddresses[i]);
                        require(
                            token.balanceOf(msg.sender) >= amounts[i], 
                            "Insufficient token balance"
                        );
                        require(
                            token.allowance(msg.sender, address(this)) >= amounts[i], 
                            "Insufficient token allowance"
                        );
                    }
                    // For ERC721 tokens
                    else {
                        IERC721 nft = IERC721(tokenAddresses[i]);
                        require(
                            nft.ownerOf(tokenIds[i]) == msg.sender, 
                            "Not the NFT owner"
                        );
                        require(
                            nft.isApprovedForAll(msg.sender, address(this)) || 
                            nft.getApproved(tokenIds[i]) == address(this), 
                            "NFT not approved"
                        );
                    }
                }
            }
            
            // Increment exchange ID counter
            _exchangeIdCounter.increment();
            uint256 newExchangeId = _exchangeIdCounter.current();
            
            // Create new exchange
            Exchange storage newExchange = exchanges[newExchangeId];
            newExchange.name = names[i];
            newExchange.description = descriptions[i];
            newExchange.exchangeType = exchangeTypes[i];
            newExchange.creator = msg.sender;
            newExchange.creationTime = block.timestamp;
            newExchange.tokenAddress = tokenAddresses[i];
            newExchange.tokenId = tokenIds[i];
            newExchange.amount = amounts[i];
            newExchange.price = prices[i];
            newExchange.isFulfilled = false;
            newExchange.isCancelled = false;
            newExchange.conditions = conditions[i];
            
            // If deadline is not set, set a default expiration (30 days)
            if (conditions[i].deadline == 0) {
                newExchange.expirationTime = block.timestamp + 30 days;
            } else {
                newExchange.expirationTime = conditions[i].deadline;
            }
            
            // Add to user's exchanges
            userExchanges[msg.sender].add(newExchangeId);
            
            // Calculate platform fee for this exchange
            uint256 platformFeeAmount = (prices[i].mul(platformFee)).div(FEE_DENOMINATOR);
            
            emit FeePaid(msg.sender, platformFeeAmount, "Exchange Creation");
            emit ExchangeCreated(newExchangeId, msg.sender, exchangeTypes[i]);
        }
        
        // Deduct total platform fee
        userBalances[msg.sender] = userBalances[msg.sender].sub(totalPlatformFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(totalPlatformFee);
    }
    
    // Batch cancel exchanges
    function batchCancelExchanges(uint256[] calldata exchangeIds) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
        withinBatchLimit(exchangeIds.length)
    {
        for (uint256 i = 0; i < exchangeIds.length; i++) {
            uint256 exchangeId = exchangeIds[i];
            
            require(exchangeId > 0 && exchangeId <= _exchangeIdCounter.current(), "Invalid exchange ID");
            
            Exchange storage exchange = exchanges[exchangeId];
            
            require(
                exchange.creator == msg.sender || owner() == msg.sender, 
                "Only creator or owner can cancel"
            );
            require(!exchange.isFulfilled, "Exchange already fulfilled");
            require(!exchange.isCancelled, "Exchange already cancelled");
            
            exchange.isCancelled = true;
            
            emit ExchangeCancelled(exchangeId, msg.sender, block.timestamp);
        }
    }
    
    // Get active exchanges by type
    function getActiveExchangesByType(ExchangeType exchangeType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count active exchanges of the specified type
        for (uint256 i = 1; i <= _exchangeIdCounter.current(); i++) {
            if (
                exchanges[i].exchangeType == exchangeType &&
                !exchanges[i].isFulfilled &&
                !exchanges[i].isCancelled &&
                block.timestamp < exchanges[i].expirationTime
            ) {
                count++;
            }
        }
        
        // Create array to hold matching exchange IDs
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill the array
        for (uint256 i = 1; i <= _exchangeIdCounter.current(); i++) {
            if (
                exchanges[i].exchangeType == exchangeType &&
                !exchanges[i].isFulfilled &&
                !exchanges[i].isCancelled &&
                block.timestamp < exchanges[i].expirationTime
            ) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Get exchanges by token address
    function getExchangesByToken(address tokenAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count exchanges for the specified token
        for (uint256 i = 1; i <= _exchangeIdCounter.current(); i++) {
            if (
                exchanges[i].tokenAddress == tokenAddress &&
                !exchanges[i].isCancelled
            ) {
                count++;
            }
        }
        
        // Create array to hold matching exchange IDs
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill the array
        for (uint256 i = 1; i <= _exchangeIdCounter.current(); i++) {
            if (
                exchanges[i].tokenAddress == tokenAddress &&
                !exchanges[i].isCancelled
            ) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // ==================== ADVANCED RESOURCE MANAGEMENT FUNCTIONS ====================
    
    // Split a resource into multiple resources
    function splitResource(
        uint256 resourceId, 
        uint256[] calldata amounts, 
        string[] calldata names,
        string[] calldata descriptions
    ) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        activeResource(resourceId) 
        nonReentrant 
        securityCheck 
        withinBatchLimit(amounts.length)
    {
        require(amounts.length == names.length, "Arrays length mismatch");
        require(amounts.length == descriptions.length, "Arrays length mismatch");
        
        Resource storage originalResource = resources[resourceId];
        require(originalResource.resourceType == ResourceType.FUNGIBLE, "Only fungible resources can be split");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount.add(amounts[i]);
        }
        
        require(originalResource.availableSupply >= totalAmount, "Insufficient available supply");
        
        // Reduce original resource supply
        originalResource.availableSupply = originalResource.availableSupply.sub(totalAmount);
        originalResource.updateTime = block.timestamp;
        
        // Create new resources
        for (uint256 i = 0; i < amounts.length; i++) {
            require(bytes(names[i]).length > 0, "Name cannot be empty");
            require(bytes(descriptions[i]).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
            
            // Increment resource ID counter
            _resourceIdCounter.increment();
            uint256 newResourceId = _resourceIdCounter.current();
            
            // Create new resource
            Resource storage newResource = resources[newResourceId];
            newResource.name = names[i];
            newResource.description = descriptions[i];
            newResource.resourceType = originalResource.resourceType;
            newResource.owner = msg.sender;
            newResource.creationTime = block.timestamp;
            newResource.updateTime = block.timestamp;
            newResource.totalSupply = amounts[i];
            newResource.availableSupply = amounts[i];
            newResource.price = originalResource.price;
            newResource.isActive = true;
            newResource.metadataURI = originalResource.metadataURI;
            newResource.properties = originalResource.properties;
            
            // Add to user's owned resources
            ownedResources[msg.sender].add(newResourceId);
            
            emit ResourceCreated(newResourceId, msg.sender, names[i]);
        }
        
        emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
    }
    
    // Merge multiple resources into one
    function mergeResources(
        uint256[] calldata resourceIds, 
        string memory newName,
        string memory newDescription
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
        withinBatchLimit(resourceIds.length)
    {
        require(resourceIds.length > 1, "At least two resources required");
        require(bytes(newName).length > 0, "Name cannot be empty");
        require(bytes(newDescription).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        
        // Check ownership and resource type
        ResourceType resourceType;
        uint256 totalSupply = 0;
        uint256 availableSupply = 0;
        
        for (uint256 i = 0; i < resourceIds.length; i++) {
            uint256 resourceId = resourceIds[i];
            
            require(resourceId > 0 && resourceId <= _resourceIdCounter.current(), "Invalid resource ID");
            require(resources[resourceId].owner == msg.sender, "Not the resource owner");
            require(resources[resourceId].isActive, "Resource is not active");
            
            if (i == 0) {
                resourceType = resources[resourceId].resourceType;
            } else {
                require(resources[resourceId].resourceType == resourceType, "Resource types must match");
            }
            
            totalSupply = totalSupply.add(resources[resourceId].totalSupply);
            availableSupply = availableSupply.add(resources[resourceId].availableSupply);
            
            // Deactivate the source resource
            resources[resourceId].isActive = false;
            resources[resourceId].updateTime = block.timestamp;
            
            emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
        }
        
        // Create new merged resource
        _resourceIdCounter.increment();
        uint256 newResourceId = _resourceIdCounter.current();
        
        // Create new resource
        Resource storage newResource = resources[newResourceId];
        newResource.name = newName;
        newResource.description = newDescription;
        newResource.resourceType = resourceType;
        newResource.owner = msg.sender;
        newResource.creationTime = block.timestamp;
        newResource.updateTime = block.timestamp;
        newResource.totalSupply = totalSupply;
        newResource.availableSupply = availableSupply;
        newResource.price = resources[resourceIds[0]].price; // Use price from first resource
        newResource.isActive = true;
        newResource.metadataURI = resources[resourceIds[0]].metadataURI; // Use metadata URI from first resource
        newResource.properties = resources[resourceIds[0]].properties; // Use properties from first resource
        
        // Add to user's owned resources
        ownedResources[msg.sender].add(newResourceId);
        
        emit ResourceCreated(newResourceId, msg.sender, newName);
    }
    
// END OF PART 5/12 - CONTINUE TO PART 6/12

// SPDX-License-Identifier: MIT
// PART 6/12 - MonadEcosystemHubV1
// Token & NFT Management Functions
// Continues from PART 5/12

// CONTINUED FROM PART 5/12

    // ==================== TOKEN & NFT MANAGEMENT FUNCTIONS ====================
    
    // Create a new ERC20-like token tracking in the hub
    function registerToken(
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory description,
        string memory logoURI
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(tokenAddress != address(0), "Invalid token address");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        
        // Check if token is already registered as a resource
        bool isRegistered = false;
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            if (
                resources[i].resourceType == ResourceType.FUNGIBLE &&
                compareStrings(resources[i].name, name) &&
                compareStrings(resources[i].description, description)
            ) {
                isRegistered = true;
                break;
            }
        }
        
        require(!isRegistered, "Token already registered");
        
        // Create a new resource for this token
        _resourceIdCounter.increment();
        uint256 newResourceId = _resourceIdCounter.current();
        
        // Create new resource
        Resource storage newResource = resources[newResourceId];
        newResource.name = name;
        newResource.description = description;
        newResource.resourceType = ResourceType.FUNGIBLE;
        newResource.owner = msg.sender;
        newResource.creationTime = block.timestamp;
        newResource.updateTime = block.timestamp;
        newResource.totalSupply = 0; // Will be updated based on actual token supply
        newResource.availableSupply = 0;
        newResource.price = 0;
        newResource.isActive = true;
        newResource.metadataURI = logoURI;
        
        // Set properties
        newResource.properties.isTransferable = true;
        newResource.properties.isBurnable = true;
        newResource.properties.isLockable = false;
        newResource.properties.maxPerUser = 0; // No limit
        
        // Add to user's owned resources
        ownedResources[msg.sender].add(newResourceId);
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = 0.01 ether;
        require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        emit FeePaid(msg.sender, platformFeeAmount, "Token Registration");
        emit ResourceCreated(newResourceId, msg.sender, name);
    }
    
    // Register an NFT collection
    function registerNFTCollection(
        address nftAddress,
        string memory name,
        string memory symbol,
        string memory description,
        string memory collectionURI
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        
        // Check if collection is already registered as a resource
        bool isRegistered = false;
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            if (
                resources[i].resourceType == ResourceType.NON_FUNGIBLE &&
                compareStrings(resources[i].name, name) &&
                compareStrings(resources[i].description, description)
            ) {
                isRegistered = true;
                break;
            }
        }
        
        require(!isRegistered, "NFT collection already registered");
        
        // Create a new resource for this NFT collection
        _resourceIdCounter.increment();
        uint256 newResourceId = _resourceIdCounter.current();
        
        // Create new resource
        Resource storage newResource = resources[newResourceId];
        newResource.name = name;
        newResource.description = description;
        newResource.resourceType = ResourceType.NON_FUNGIBLE;
        newResource.owner = msg.sender;
        newResource.creationTime = block.timestamp;
        newResource.updateTime = block.timestamp;
        newResource.totalSupply = 0; // Will be updated based on actual NFT supply
        newResource.availableSupply = 0;
        newResource.price = 0;
        newResource.isActive = true;
        newResource.metadataURI = collectionURI;
        
        // Set properties
        newResource.properties.isTransferable = true;
        newResource.properties.isBurnable = true;
        newResource.properties.isLockable = false;
        newResource.properties.maxPerUser = 0; // No limit
        
        // Add to user's owned resources
        ownedResources[msg.sender].add(newResourceId);
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = 0.01 ether;
        require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        emit FeePaid(msg.sender, platformFeeAmount, "NFT Collection Registration");
        emit ResourceCreated(newResourceId, msg.sender, name);
    }
    
    // Link an NFT to a resource
    function linkNFTToResource(
        uint256 resourceId,
        address nftAddress,
        uint256 tokenId
    ) 
        external 
        whenNotPaused 
        onlyResourceOwner(resourceId) 
        validResourceId(resourceId) 
        nonReentrant 
        securityCheck 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        
        // Verify caller owns the NFT
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        
        // Update resource metadata
        resources[resourceId].metadataURI = string(
            abi.encodePacked(
                resources[resourceId].metadataURI,
                ",nft:",
                Strings.toHexString(uint160(nftAddress)),
                "/",
                tokenId.toString()
            )
        );
        resources[resourceId].updateTime = block.timestamp;
        
        emit ResourceUpdated(resourceId, msg.sender, block.timestamp);
    }
    
    // Get user's token balances
    function getUserTokens(address user) 
        external 
        view 
        returns (address[] memory) 
    {
        uint256 count = userTokens[user].length();
        address[] memory tokens = new address[](count);
        
        for (uint256 i = 0; i < count; i++) {
            tokens[i] = userTokens[user].at(i);
        }
        
        return tokens;
    }
    
    // Get user's token balance for a specific token
    function getUserTokenBalance(address user, address token) 
        external 
        view 
        returns (uint256) 
    {
        return tokenBalances[user][token];
    }
    
    // Batch deposit tokens
    function batchDepositTokens(
        address[] calldata tokenAddresses,
        uint256[] calldata amounts
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        withinBatchLimit(tokenAddresses.length)
    {
        require(tokenAddresses.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            uint256 amount = amounts[i];
            
            require(amount > 0, "Deposit amount must be greater than 0");
            require(tokenAddress != address(0), "Invalid token address");
            
            IERC20 token = IERC20(tokenAddress);
            require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
            
            tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].add(amount);
            userTokens[msg.sender].add(tokenAddress);
            
            emit TokenDeposited(msg.sender, tokenAddress, amount);
        }
    }
    
    // Batch withdraw tokens
    function batchWithdrawTokens(
        address[] calldata tokenAddresses,
        uint256[] calldata amounts
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        withinBatchLimit(tokenAddresses.length)
    {
        require(tokenAddresses.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            uint256 amount = amounts[i];
            
            require(amount > 0, "Withdrawal amount must be greater than 0");
            require(tokenAddress != address(0), "Invalid token address");
            require(tokenBalances[msg.sender][tokenAddress] >= amount, "Insufficient token balance");
            
            tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].sub(amount);
            
            if (tokenBalances[msg.sender][tokenAddress] == 0) {
                userTokens[msg.sender].remove(tokenAddress);
            }
            
            IERC20 token = IERC20(tokenAddress);
            require(token.transfer(msg.sender, amount), "Transfer failed");
            
            emit TokenWithdrawn(msg.sender, tokenAddress, amount);
        }
    }
    // CONTINUED FROM PART 6.1/12

    // Transfer tokens between users in the system
    function transferTokensBetweenUsers(
        address tokenAddress,
        address toUser,
        uint256 amount
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(toUser != address(0), "Invalid recipient address");
        require(isRegistered[toUser], "Recipient not registered");
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(tokenBalances[msg.sender][tokenAddress] >= amount, "Insufficient token balance");
        
        // Update token balances
        tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].sub(amount);
        tokenBalances[toUser][tokenAddress] = tokenBalances[toUser][tokenAddress].add(amount);
        
        // Update user tokens tracking
        if (tokenBalances[msg.sender][tokenAddress] == 0) {
            userTokens[msg.sender].remove(tokenAddress);
        }
        
        userTokens[toUser].add(tokenAddress);
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = (amount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 transferAmount = amount.sub(platformFeeAmount);
        
        // Add fee to fee collector's token balance
        tokenBalances[feeCollector][tokenAddress] = tokenBalances[feeCollector][tokenAddress].add(platformFeeAmount);
        userTokens[feeCollector].add(tokenAddress);
        
        // Adjust recipient's token amount to account for fee
        tokenBalances[toUser][tokenAddress] = tokenBalances[toUser][tokenAddress].sub(platformFeeAmount);
        
        emit TokenDeposited(toUser, tokenAddress, transferAmount);
        emit TokenWithdrawn(msg.sender, tokenAddress, amount);
        emit FeePaid(msg.sender, platformFeeAmount, "Token Transfer");
    }
    
    // Create a token swap between users
    function createTokenSwap(
        address tokenOfferedAddress,
        uint256 tokenOfferedAmount,
        address tokenRequestedAddress,
        uint256 tokenRequestedAmount,
        uint256 expirationTime
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(tokenOfferedAddress != address(0), "Invalid offered token address");
        require(tokenRequestedAddress != address(0), "Invalid requested token address");
        require(tokenOfferedAmount > 0, "Offered amount must be greater than 0");
        require(tokenRequestedAmount > 0, "Requested amount must be greater than 0");
        require(tokenBalances[msg.sender][tokenOfferedAddress] >= tokenOfferedAmount, "Insufficient token balance");
        require(expirationTime > block.timestamp, "Expiration time must be in the future");
        
        // Create a new exchange for the token swap
        _exchangeIdCounter.increment();
        uint256 newExchangeId = _exchangeIdCounter.current();
        
        // Create new exchange
        Exchange storage newExchange = exchanges[newExchangeId];
        newExchange.name = "Token Swap";
        newExchange.description = string(abi.encodePacked(
            "Swap ", tokenOfferedAmount.toString(), " of token ", 
            Strings.toHexString(uint160(tokenOfferedAddress)), 
            " for ", tokenRequestedAmount.toString(), " of token ",
            Strings.toHexString(uint160(tokenRequestedAddress))
        ));
        newExchange.exchangeType = ExchangeType.SWAP;
        newExchange.creator = msg.sender;
        newExchange.creationTime = block.timestamp;
        newExchange.expirationTime = expirationTime;
        newExchange.tokenAddress = tokenOfferedAddress;
        newExchange.amount = tokenOfferedAmount;
        newExchange.price = tokenRequestedAmount; // Repurposing price field for requested amount
        newExchange.isFulfilled = false;
        newExchange.isCancelled = false;
        
        // Setup swap-specific conditions
        ExchangeConditions memory conditions;
        conditions.deadline = expirationTime;
        conditions.allowPartialFills = false;
        newExchange.conditions = conditions;
        
        // Add to user's exchanges
        userExchanges[msg.sender].add(newExchangeId);
        
        // Lock the offered tokens by transferring to contract's management
        // (tokens remain in user's balance but are marked as in-swap)
        tokenBalances[msg.sender][tokenOfferedAddress] = tokenBalances[msg.sender][tokenOfferedAddress].sub(tokenOfferedAmount);
        
        // Create a special entry in the exchange participation mapping to track the locked tokens
        exchangeParticipation[newExchangeId][msg.sender] = tokenOfferedAmount;
        
        emit ExchangeCreated(newExchangeId, msg.sender, ExchangeType.SWAP);
    }
    
    // Accept a token swap
    function acceptTokenSwap(uint256 exchangeId) 
        external 
        whenNotPaused 
        validExchangeId(exchangeId) 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        Exchange storage exchange = exchanges[exchangeId];
        
        require(exchange.exchangeType == ExchangeType.SWAP, "Not a token swap");
        require(!exchange.isFulfilled, "Swap already fulfilled");
        require(!exchange.isCancelled, "Swap cancelled");
        require(block.timestamp < exchange.expirationTime, "Swap expired");
        require(msg.sender != exchange.creator, "Cannot accept own swap");
        
        // Extract swap details
        address tokenOfferedAddress = exchange.tokenAddress;
        uint256 tokenOfferedAmount = exchange.amount;
        uint256 tokenRequestedAmount = exchange.price; // Repurposed price field
        
        // Determine requested token address from exchange description
        // This is a simplified approach; in a real implementation you would store this more explicitly
        string memory description = exchange.description;
        bytes memory descBytes = bytes(description);
        uint256 lastSpaceIndex = 0;
        
        // Find the last space in the description to extract the token address
        for (uint256 i = 0; i < descBytes.length; i++) {
            if (descBytes[i] == ' ') {
                lastSpaceIndex = i;
            }
        }
        
        // Extract the token address from the description
        string memory tokenRequestedAddressStr = "";
        for (uint256 i = lastSpaceIndex + 1; i < descBytes.length; i++) {
            tokenRequestedAddressStr = string(abi.encodePacked(tokenRequestedAddressStr, descBytes[i]));
        }
        
        // Convert string to address (simplified)
        address tokenRequestedAddress = address(uint160(parseHexString(tokenRequestedAddressStr)));
        
        // Check if acceptor has enough requested tokens
        require(tokenBalances[msg.sender][tokenRequestedAddress] >= tokenRequestedAmount, "Insufficient requested token balance");
        
        // Update token balances for both parties
        // 1. Swap creator receives requested tokens
        tokenBalances[exchange.creator][tokenRequestedAddress] = tokenBalances[exchange.creator][tokenRequestedAddress].add(tokenRequestedAmount);
        userTokens[exchange.creator].add(tokenRequestedAddress);
        
        // 2. Swap acceptor receives offered tokens
        tokenBalances[msg.sender][tokenOfferedAddress] = tokenBalances[msg.sender][tokenOfferedAddress].add(tokenOfferedAmount);
        userTokens[msg.sender].add(tokenOfferedAddress);
        
        // 3. Remove requested tokens from acceptor
        tokenBalances[msg.sender][tokenRequestedAddress] = tokenBalances[msg.sender][tokenRequestedAddress].sub(tokenRequestedAmount);
        if (tokenBalances[msg.sender][tokenRequestedAddress] == 0) {
            userTokens[msg.sender].remove(tokenRequestedAddress);
        }
        
        // Mark exchange as fulfilled
        exchange.isFulfilled = true;
        
        // Add to acceptor's exchanges
        userExchanges[msg.sender].add(exchangeId);
        
        // Calculate and charge platform fee (from both parties)
        uint256 creatorFee = (tokenRequestedAmount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 acceptorFee = (tokenOfferedAmount.mul(platformFee)).div(FEE_DENOMINATOR);
        
        // Update fee collector's token balances
        tokenBalances[feeCollector][tokenRequestedAddress] = tokenBalances[feeCollector][tokenRequestedAddress].add(creatorFee);
        tokenBalances[feeCollector][tokenOfferedAddress] = tokenBalances[feeCollector][tokenOfferedAddress].add(acceptorFee);
        userTokens[feeCollector].add(tokenRequestedAddress);
        userTokens[feeCollector].add(tokenOfferedAddress);
        
        // Deduct fees from received amounts
        tokenBalances[exchange.creator][tokenRequestedAddress] = tokenBalances[exchange.creator][tokenRequestedAddress].sub(creatorFee);
        tokenBalances[msg.sender][tokenOfferedAddress] = tokenBalances[msg.sender][tokenOfferedAddress].sub(acceptorFee);
        
        emit ExchangeFulfilled(exchangeId, msg.sender, block.timestamp);
        emit FeePaid(exchange.creator, creatorFee, "Token Swap");
        emit FeePaid(msg.sender, acceptorFee, "Token Swap");
    }
    
    // Parse hex string to uint (helper function)
    function parseHexString(string memory hexString) internal pure returns (uint256) {
        bytes memory bytesString = bytes(hexString);
        uint256 result = 0;
        for (uint256 i = 0; i < bytesString.length; i++) {
            uint256 charValue;
            bytes1 char = bytesString[i];
            
            if (char >= 0x30 && char <= 0x39) {
                charValue = uint256(uint8(char)) - 0x30;
            } else if (char >= 0x41 && char <= 0x46) {
                charValue = uint256(uint8(char)) - 0x41 + 10;
            } else if (char >= 0x61 && char <= 0x66) {
                charValue = uint256(uint8(char)) - 0x61 + 10;
            } else {
                continue; // Skip non-hex characters
            }
            
            result = result * 16 + charValue;
        }
        return result;
    }
    
    // Deposit NFT into the system
    function depositNFT(
        address nftAddress,
        uint256 tokenId
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        
        // Verify caller owns the NFT
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        
        // Transfer NFT to contract
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        
        // Update user's record of NFT ownership within the system
        // We'll use a special format in tokenBalances:
        // tokenBalances[user][nftAddress] will store a bitmap of owned tokenIds
        // This is a simplified approach and would need to be enhanced for a real implementation
        tokenBalances[msg.sender][nftAddress] = tokenBalances[msg.sender][nftAddress] | (1 << (tokenId % 256));
        userTokens[msg.sender].add(nftAddress);
        
        emit TokenDeposited(msg.sender, nftAddress, tokenId);
    }
    
    // Withdraw NFT from the system
    function withdrawNFT(
        address nftAddress,
        uint256 tokenId
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        
        // Check if user owns this NFT in the system
        require(
            (tokenBalances[msg.sender][nftAddress] & (1 << (tokenId % 256))) != 0,
            "NFT not owned in system"
        );
        
        // Update user's record of NFT ownership
        tokenBalances[msg.sender][nftAddress] = tokenBalances[msg.sender][nftAddress] & ~(1 << (tokenId % 256));
        
        // If user has no more NFTs from this collection, remove from userTokens
        if (tokenBalances[msg.sender][nftAddress] == 0) {
            userTokens[msg.sender].remove(nftAddress);
        }
        
        // Transfer NFT back to user
        IERC721 nft = IERC721(nftAddress);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit TokenWithdrawn(msg.sender, nftAddress, tokenId);
    }
    
    // Get token metadata
    function getTokenMetadata(address tokenAddress) 
        external 
        view 
        returns (
            string memory name,
            string memory symbol,
            uint8 decimals,
            uint256 totalSupply
        ) 
    {
        require(tokenAddress != address(0), "Invalid token address");
        
        IERC20Metadata token = IERC20Metadata(tokenAddress);
        
        // Use try-catch for external calls to handle tokens that don't implement ERC20Metadata
        try token.name() returns (string memory _name) {
            name = _name;
        } catch {
            name = "Unknown";
        }
        
        try token.symbol() returns (string memory _symbol) {
            symbol = _symbol;
        } catch {
            symbol = "???";
        }
        
        try token.decimals() returns (uint8 _decimals) {
            decimals = _decimals;
        } catch {
            decimals = 18; // Default to 18 if not specified
        }
        
        try token.totalSupply() returns (uint256 _totalSupply) {
            totalSupply = _totalSupply;
        } catch {
            totalSupply = 0;
        }
    }
    
    // Get NFT metadata
    function getNFTMetadata(address nftAddress, uint256 tokenId) 
        external 
        view 
        returns (
            string memory tokenURI,
            address owner
        ) 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        
        IERC721 nft = IERC721(nftAddress);
        
        // Check if NFT exists
        try nft.ownerOf(tokenId) returns (address _owner) {
            owner = _owner;
            
            // Get token URI
            try IERC721Metadata(nftAddress).tokenURI(tokenId) returns (string memory _tokenURI) {
                tokenURI = _tokenURI;
            } catch {
                tokenURI = "";
            }
        } catch {
            // NFT doesn't exist or doesn't implement ownerOf
            owner = address(0);
            tokenURI = "";
        }
    }
    
    // Batch transfer tokens
    function batchTransferTokens(
        address[] calldata toUsers,
        address[] calldata tokenAddresses,
        uint256[] calldata amounts
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(toUsers.length)
    {
        require(toUsers.length == tokenAddresses.length, "Arrays length mismatch");
        require(tokenAddresses.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalPlatformFee = 0;
        
        for (uint256 i = 0; i < toUsers.length; i++) {
            address toUser = toUsers[i];
            address tokenAddress = tokenAddresses[i];
            uint256 amount = amounts[i];
            
            require(toUser != address(0), "Invalid recipient address");
            require(isRegistered[toUser], "Recipient not registered");
            require(tokenAddress != address(0), "Invalid token address");
            require(amount > 0, "Amount must be greater than 0");
            require(tokenBalances[msg.sender][tokenAddress] >= amount, "Insufficient token balance");
            
            // Update token balances
            tokenBalances[msg.sender][tokenAddress] = tokenBalances[msg.sender][tokenAddress].sub(amount);
            
            // Calculate platform fee
            uint256 platformFeeAmount = (amount.mul(platformFee)).div(FEE_DENOMINATOR);
            uint256 transferAmount = amount.sub(platformFeeAmount);
            
            // Update recipient balance
            tokenBalances[toUser][tokenAddress] = tokenBalances[toUser][tokenAddress].add(transferAmount);
            userTokens[toUser].add(tokenAddress);
            
            // Add fee to fee collector's token balance
            tokenBalances[feeCollector][tokenAddress] = tokenBalances[feeCollector][tokenAddress].add(platformFeeAmount);
            userTokens[feeCollector].add(tokenAddress);
            
            // Update user tokens tracking
            if (tokenBalances[msg.sender][tokenAddress] == 0) {
                userTokens[msg.sender].remove(tokenAddress);
            }
            
            totalPlatformFee = totalPlatformFee.add(platformFeeAmount);
            
            emit TokenDeposited(toUser, tokenAddress, transferAmount);
            emit TokenWithdrawn(msg.sender, tokenAddress, amount);
        }
        
        emit FeePaid(msg.sender, totalPlatformFee, "Batch Token Transfer");
    }
    
    // Get NFTs owned by a user
    function getUserNFTs(address user, address nftAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        require(nftAddress != address(0), "Invalid NFT address");
        
        // Get the bitmap of owned NFTs
        uint256 bitmap = tokenBalances[user][nftAddress];
        
        // Count how many bits are set
        uint256 count = 0;
        uint256 tempBitmap = bitmap;
        while (tempBitmap > 0) {
            if (tempBitmap & 1 != 0) {
                count++;
            }
            tempBitmap >>= 1;
        }
        
        // Create result array
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill result array
        for (uint256 i = 0; i < 256; i++) {
            if ((bitmap & (1 << i)) != 0) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Check if a user owns a specific NFT in the system
    function hasNFT(address user, address nftAddress, uint256 tokenId) 
        external 
        view 
        returns (bool) 
    {
        return (tokenBalances[user][nftAddress] & (1 << (tokenId % 256))) != 0;
    }
    
    // Get tokens and NFTs by type
    function getTokensByType(bool isNFT) 
        external 
        view 
        returns (address[] memory) 
    {
        uint256 resourceCount = _resourceIdCounter.current();
        uint256 count = 0;
        
        // Count tokens of the requested type
        for (uint256 i = 1; i <= resourceCount; i++) {
            if (
                (isNFT && resources[i].resourceType == ResourceType.NON_FUNGIBLE) ||
                (!isNFT && resources[i].resourceType == ResourceType.FUNGIBLE)
            ) {
                count++;
            }
        }
        
        // Create result array
        address[] memory result = new address[](count);
        uint256 index = 0;
        
        // Find resource IDs of the specified type
        for (uint256 i = 1; i <= resourceCount && index < count; i++) {
            if (
                (isNFT && resources[i].resourceType == ResourceType.NON_FUNGIBLE) ||
                (!isNFT && resources[i].resourceType == ResourceType.FUNGIBLE)
            ) {
                // This is a simplified approach to extract token addresses
                // In a real implementation, you'd store token addresses more explicitly
                bytes memory metadataBytes = bytes(resources[i].metadataURI);
                if (metadataBytes.length >= 42) { // Minimum length for a URI with an address
                    // Extract token address from metadata URI
                    // This is just a placeholder implementation and would need to be more robust
                    result[index] = address(uint160(parseHexString(string(metadataBytes))));
                    index++;
                }
            }
        }
        
        return result;
    }
    
    // Calculate the total value of a user's tokens
    function calculateUserTokensValue(address user) 
        external 
        view 
        returns (uint256) 
    {
        uint256 totalValue = 0;
        uint256 tokenCount = userTokens[user].length();
        
        for (uint256 i = 0; i < tokenCount; i++) {
            address tokenAddress = userTokens[user].at(i);
            uint256 balance = tokenBalances[user][tokenAddress];
            
            // Skip if balance is zero
            if (balance == 0) continue;
            
            // Find resource ID for this token to get its price
            uint256 resourceId = 0;
            for (uint256 j = 1; j <= _resourceIdCounter.current(); j++) {
                bytes memory metadataBytes = bytes(resources[j].metadataURI);
                if (metadataBytes.length >= 42) {
                    // Extract token address from metadata URI (simplified)
                    address tokenFromMetadata = address(uint160(parseHexString(string(metadataBytes))));
                    if (tokenFromMetadata == tokenAddress) {
                        resourceId = j;
                        break;
                    }
                }
            }
            
            // If found a resource for this token, use its price
            if (resourceId > 0) {
                totalValue = totalValue.add(balance.mul(resources[resourceId].price));
            }
        }
        
        return totalValue;
    }
    
// END OF PART 6/12 - CONTINUE TO PART 7/12
// SPDX-License-Identifier: MIT
// PART 7/12 - MonadEcosystemHubV1
// Integration & Cross-Chain Functions
// Continues from PART 6/12

// CONTINUED FROM PART 6/12

    // ==================== INTEGRATION & CROSS-CHAIN FUNCTIONS ====================
    
    // Structure for cross-chain message
    struct CrossChainMessage {
        uint256 id;
        address sender;
        uint256 sourceChainId;
        uint256 targetChainId;
        bytes message;
        CrossChainMessageStatus status;
        uint256 timestamp;
        uint256 fee;
        bytes32 hash;
    }
    
    // Enum for cross-chain message status
    enum CrossChainMessageStatus { PENDING, SENT, DELIVERED, FAILED }
    
    // Mapping for cross-chain messages
    mapping(uint256 => CrossChainMessage) public crossChainMessages;
    mapping(bytes32 => bool) public processedMessages;
    
    // Counter for cross-chain messages
    Counters.Counter private _messageIdCounter;
    
    // Event for cross-chain message
    event CrossChainMessageSent(uint256 indexed messageId, address indexed sender, uint256 sourceChainId, uint256 targetChainId);
    event CrossChainMessageReceived(uint256 indexed messageId, address indexed sender, uint256 sourceChainId, uint256 targetChainId);
    event CrossChainMessageProcessed(uint256 indexed messageId, bool success);
    
    // Send a cross-chain message
    function sendCrossChainMessage(
        uint256 targetChainId,
        bytes memory message
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(targetChainId != block.chainid, "Cannot send to same chain");
        require(message.length > 0, "Empty message");
        require(message.length <= 2048, "Message too long");
        
        // Calculate fee for cross-chain message
        uint256 messageFee = 0.001 ether;
        require(msg.value >= messageFee, "Insufficient fee");
        
        // Get current chain ID
        uint256 sourceChainId = block.chainid;
        
        // Increment message ID counter
        _messageIdCounter.increment();
        uint256 newMessageId = _messageIdCounter.current();
        
        // Create message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                newMessageId,
                msg.sender,
                sourceChainId,
                targetChainId,
                message,
                block.timestamp
            )
        );
        
        // Create new cross-chain message
        CrossChainMessage storage newMessage = crossChainMessages[newMessageId];
        newMessage.id = newMessageId;
        newMessage.sender = msg.sender;
        newMessage.sourceChainId = sourceChainId;
        newMessage.targetChainId = targetChainId;
        newMessage.message = message;
        newMessage.status = CrossChainMessageStatus.SENT;
        newMessage.timestamp = block.timestamp;
        newMessage.fee = messageFee;
        newMessage.hash = messageHash;
        
        // Transfer fee to fee collector
        userBalances[feeCollector] = userBalances[feeCollector].add(messageFee);
        
        // Refund excess payment
        if (msg.value > messageFee) {
            (bool success, ) = msg.sender.call{value: msg.value - messageFee}("");
            require(success, "Refund failed");
        }
        
        emit CrossChainMessageSent(newMessageId, msg.sender, sourceChainId, targetChainId);
        emit FeePaid(msg.sender, messageFee, "Cross-Chain Message");
    }
    
    // Receive a cross-chain message (only callable by approved cross-chain bridges)
    function receiveCrossChainMessage(
        uint256 messageId,
        address sender,
        uint256 sourceChainId,
        bytes memory message,
        bytes32 messageHash
    ) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(!processedMessages[messageHash], "Message already processed");
        
        // Verify message hash
        bytes32 calculatedHash = keccak256(
            abi.encodePacked(
                messageId,
                sender,
                sourceChainId,
                block.chainid,
                message,
                block.timestamp
            )
        );
        
        require(calculatedHash == messageHash, "Invalid message hash");
        
        // Mark message as processed
        processedMessages[messageHash] = true;
        
        // Store received message
        _messageIdCounter.increment();
        uint256 newMessageId = _messageIdCounter.current();
        
        CrossChainMessage storage newMessage = crossChainMessages[newMessageId];
        newMessage.id = messageId;
        newMessage.sender = sender;
        newMessage.sourceChainId = sourceChainId;
        newMessage.targetChainId = block.chainid;
        newMessage.message = message;
        newMessage.status = CrossChainMessageStatus.DELIVERED;
        newMessage.timestamp = block.timestamp;
        newMessage.hash = messageHash;
        
        emit CrossChainMessageReceived(messageId, sender, sourceChainId, block.chainid);
        
        // Process message
        (bool success, ) = address(this).call(message);
        
        emit CrossChainMessageProcessed(messageId, success);
    }
    
    // Get cross-chain message details
    function getCrossChainMessage(uint256 messageId) 
        external 
        view 
        returns (
            address sender,
            uint256 sourceChainId,
            uint256 targetChainId,
            CrossChainMessageStatus status,
            uint256 timestamp,
            bytes32 hash
        ) 
    {
        CrossChainMessage storage message = crossChainMessages[messageId];
        
        return (
            message.sender,
            message.sourceChainId,
            message.targetChainId,
            message.status,
            message.timestamp,
            message.hash
        );
    }
    
    // Get cross-chain message count
    function getCrossChainMessageCount() 
        external 
        view 
        returns (uint256) 
    {
        return _messageIdCounter.current();
    }
    
    // Verify cross-chain message hash
    function verifyCrossChainMessageHash(
        uint256 messageId,
        address sender,
        uint256 sourceChainId,
        uint256 targetChainId,
        bytes memory message,
        uint256 timestamp,
        bytes32 hash
    ) 
        external 
        pure 
        returns (bool) 
    {
        bytes32 calculatedHash = keccak256(
            abi.encodePacked(
                messageId,
                sender,
                sourceChainId,
                targetChainId,
                message,
                timestamp
            )
        );
        
        return calculatedHash == hash;
    }
    
    // Check if cross-chain message has been processed
    function isMessageProcessed(bytes32 messageHash) 
        external 
        view 
        returns (bool) 
    {
        return processedMessages[messageHash];
    }
    
    // ==================== EXTERNAL INTEGRATION FUNCTIONS ====================
    
    // Structure for external integration
    struct ExternalIntegration {
        uint256 id;
        string name;
        string description;
        address integrationAddress;
        bytes4 interfaceId;
        bool isActive;
        uint256 creationTime;
        IntegrationType integrationType;
    }
    
    // Enum for integration type
    enum IntegrationType { ORACLE, DEX, LENDING, MARKETPLACE, SOCIAL, OTHER }
    
    // Mapping for external integrations
    mapping(uint256 => ExternalIntegration) public externalIntegrations;
    mapping(address => bool) public approvedIntegrations;
    
    // Counter for external integrations
    Counters.Counter private _integrationIdCounter;
    
    // Event for external integration
    event ExternalIntegrationAdded(uint256 indexed integrationId, string name, address integrationAddress);
    event ExternalIntegrationUpdated(uint256 indexed integrationId, bool isActive);
    event ExternalIntegrationCalled(uint256 indexed integrationId, bytes4 selector, bool success);
    
    // Add external integration
    function addExternalIntegration(
        string memory name,
        string memory description,
        address integrationAddress,
        bytes4 interfaceId,
        IntegrationType integrationType
    ) 
        external 
        onlyOwner 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(integrationAddress != address(0), "Invalid integration address");
        
        // Increment integration ID counter
        _integrationIdCounter.increment();
        uint256 newIntegrationId = _integrationIdCounter.current();
        
        // Create new external integration
        ExternalIntegration storage newIntegration = externalIntegrations[newIntegrationId];
        newIntegration.id = newIntegrationId;
        newIntegration.name = name;
        newIntegration.description = description;
        newIntegration.integrationAddress = integrationAddress;
        newIntegration.interfaceId = interfaceId;
        newIntegration.isActive = true;
        newIntegration.creationTime = block.timestamp;
        newIntegration.integrationType = integrationType;
        
        // Approve integration
        approvedIntegrations[integrationAddress] = true;
        
        emit ExternalIntegrationAdded(newIntegrationId, name, integrationAddress);
    }
    
    // Update external integration status
    function updateExternalIntegrationStatus(uint256 integrationId, bool isActive) 
        external 
        onlyOwner 
    {
        require(integrationId > 0 && integrationId <= _integrationIdCounter.current(), "Invalid integration ID");
        
        ExternalIntegration storage integration = externalIntegrations[integrationId];
        integration.isActive = isActive;
        
        // Update approval status
        approvedIntegrations[integration.integrationAddress] = isActive;
        
        emit ExternalIntegrationUpdated(integrationId, isActive);
    }
    
    // Call external integration function
    function callExternalIntegration(
        uint256 integrationId,
        bytes memory data,
        uint256 value
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (bytes memory)
    {
        require(integrationId > 0 && integrationId <= _integrationIdCounter.current(), "Invalid integration ID");
        
        ExternalIntegration storage integration = externalIntegrations[integrationId];
        require(integration.isActive, "Integration not active");
        require(approvedIntegrations[integration.integrationAddress], "Integration not approved");
        
        // Extract function selector
        bytes4 selector;
        if (data.length >= 4) {
            assembly {
                selector := mload(add(data, 32))
            }
        }
        
        // Ensure provided value matches expected value
        require(msg.value >= value, "Insufficient value provided");
        
        // Call external integration
        (bool success, bytes memory result) = integration.integrationAddress.call{value: value}(data);
        require(success, "Integration call failed");
        
        emit ExternalIntegrationCalled(integrationId, selector, success);
        
        return result;
    }
    
    // Get external integrations by type
    function getExternalIntegrationsByType(IntegrationType integrationType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count integrations of the specified type
        for (uint256 i = 1; i <= _integrationIdCounter.current(); i++) {
            if (externalIntegrations[i].integrationType == integrationType && externalIntegrations[i].isActive) {
                count++;
            }
        }
        
        // Create array to hold matching integration IDs
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        // Fill the array
        for (uint256 i = 1; i <= _integrationIdCounter.current(); i++) {
            if (externalIntegrations[i].integrationType == integrationType && externalIntegrations[i].isActive) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Get external integration details
    function getExternalIntegrationDetails(uint256 integrationId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address integrationAddress,
            bytes4 interfaceId,
            bool isActive,
            uint256 creationTime,
            IntegrationType integrationType
        ) 
    {
        require(integrationId > 0 && integrationId <= _integrationIdCounter.current(), "Invalid integration ID");
        
        ExternalIntegration storage integration = externalIntegrations[integrationId];
        
        return (
            integration.name,
            integration.description,
            integration.integrationAddress,
            integration.interfaceId,
            integration.isActive,
            integration.creationTime,
            integration.integrationType
        );
    }
    
    // Verify if integration supports a specific interface
    function verifyExternalIntegrationInterface(uint256 integrationId, bytes4 interfaceId) 
        external 
        view 
        returns (bool) 
    {
        require(integrationId > 0 && integrationId <= _integrationIdCounter.current(), "Invalid integration ID");
        
        ExternalIntegration storage integration = externalIntegrations[integrationId];
        
        // Check if integration supports interface
        try IERC165(integration.integrationAddress).supportsInterface(interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }
    
    // Batch update external integrations
    function batchUpdateExternalIntegrations(
        uint256[] calldata integrationIds,
        bool[] calldata activeStates
    ) 
        external 
        onlyOwner 
        withinBatchLimit(integrationIds.length)
    {
        require(integrationIds.length == activeStates.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < integrationIds.length; i++) {
            uint256 integrationId = integrationIds[i];
            bool isActive = activeStates[i];
            
            require(integrationId > 0 && integrationId <= _integrationIdCounter.current(), "Invalid integration ID");
            
            ExternalIntegration storage integration = externalIntegrations[integrationId];
            integration.isActive = isActive;
            
            // Update approval status
            approvedIntegrations[integration.integrationAddress] = isActive;
            
            emit ExternalIntegrationUpdated(integrationId, isActive);
        }
    }
    
    // ==================== DEFI INTEGRATION FUNCTIONS ====================
    
    // Structure for DeFi integration
    struct DeFiIntegration {
        uint256 id;
        string name;
        string description;
        address contractAddress;
        DeFiProtocolType protocolType;
        bool isActive;
        uint256 creationTime;
        uint256 lastCallTime;
    }
    
    // Enum for DeFi protocol type
    enum DeFiProtocolType { DEX, LENDING, YIELD, DERIVATIVE, INSURANCE, OTHER }
    
    // Mapping for DeFi integrations
    mapping(uint256 => DeFiIntegration) public defiIntegrations;
    
    // Counter for DeFi integrations
    Counters.Counter private _defiIntegrationIdCounter;
    
    // Event for DeFi integration
    event DeFiIntegrationAdded(uint256 indexed integrationId, string name, address contractAddress);
    event DeFiIntegrationCalled(uint256 indexed integrationId, bytes4 selector, uint256 value);
    
    // Add DeFi protocol integration
    function addDeFiProtocolIntegration(
        string memory name,
        string memory description,
        address contractAddress,
        DeFiProtocolType protocolType
    ) 
        external 
        onlyOwner 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(contractAddress != address(0), "Invalid contract address");
        
        // Increment DeFi integration ID counter
        _defiIntegrationIdCounter.increment();
        uint256 newIntegrationId = _defiIntegrationIdCounter.current();
        
        // Create new DeFi integration
        DeFiIntegration storage newIntegration = defiIntegrations[newIntegrationId];
        newIntegration.id = newIntegrationId;
        newIntegration.name = name;
        newIntegration.description = description;
        newIntegration.contractAddress = contractAddress;
        newIntegration.protocolType = protocolType;
        newIntegration.isActive = true;
        newIntegration.creationTime = block.timestamp;
        
        emit DeFiIntegrationAdded(newIntegrationId, name, contractAddress);
    }
    
    // Interact with DEX protocol
    function swapTokensWithDEX(
        uint256 integrationId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (uint256)
    {
        require(integrationId > 0 && integrationId <= _defiIntegrationIdCounter.current(), "Invalid integration ID");
        
        DeFiIntegration storage integration = defiIntegrations[integrationId];
        require(integration.isActive, "Integration not active");
        require(integration.protocolType == DeFiProtocolType.DEX, "Not a DEX integration");
        
        // Check if user has enough tokens
        require(tokenBalances[msg.sender][tokenIn] >= amountIn, "Insufficient token balance");
        
        // Approve DEX to spend tokens
        IERC20(tokenIn).approve(integration.contractAddress, amountIn);
        
        // Construct swap function call data
        bytes memory swapData = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,uint256)",
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            deadline
        );
        
        // Deduct tokens from user balance
        tokenBalances[msg.sender][tokenIn] = tokenBalances[msg.sender][tokenIn].sub(amountIn);
        
        // Call DEX function
        (bool success, bytes memory result) = integration.contractAddress.call(swapData);
        require(success, "DEX swap failed");
        
        // Parse result to get amount received
        uint256 amountOut = abi.decode(result, (uint256));
        
        // Add received tokens to user balance
        tokenBalances[msg.sender][tokenOut] = tokenBalances[msg.sender][tokenOut].add(amountOut);
        userTokens[msg.sender].add(tokenOut);
        
        // Update last call time
        integration.lastCallTime = block.timestamp;
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = (amountOut.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 userAmount = amountOut.sub(platformFeeAmount);
        
        // Update balances to account for fee
        tokenBalances[msg.sender][tokenOut] = tokenBalances[msg.sender][tokenOut].sub(platformFeeAmount);
        tokenBalances[feeCollector][tokenOut] = tokenBalances[feeCollector][tokenOut].add(platformFeeAmount);
        userTokens[feeCollector].add(tokenOut);
        
        emit DeFiIntegrationCalled(integrationId, bytes4(keccak256("swap(address,address,uint256,uint256,uint256)")), 0);
        
        return userAmount;
    }
    
    // Interact with lending protocol
    function depositToLendingProtocol(
        uint256 integrationId,
        address token,
        uint256 amount
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (uint256)
    {
        require(integrationId > 0 && integrationId <= _defiIntegrationIdCounter.current(), "Invalid integration ID");
        
        DeFiIntegration storage integration = defiIntegrations[integrationId];
        require(integration.isActive, "Integration not active");
        require(integration.protocolType == DeFiProtocolType.LENDING, "Not a lending integration");
        
        // Check if user has enough tokens
        require(tokenBalances[msg.sender][token] >= amount, "Insufficient token balance");
        
        // Approve lending protocol to spend tokens
        IERC20(token).approve(integration.contractAddress, amount);
        
        // Construct deposit function call data
        bytes memory depositData = abi.encodeWithSignature(
            "deposit(address,uint256)",
            token,
            amount
        );
        
        // Deduct tokens from user balance
        tokenBalances[msg.sender][token] = tokenBalances[msg.sender][token].sub(amount);
        
        // Call lending protocol function
        (bool success, bytes memory result) = integration.contractAddress.call(depositData);
        require(success, "Deposit failed");
        
        // Parse result to get receipt token amount
        uint256 receiptTokenAmount = abi.decode(result, (uint256));
        
        // Store receipt token as a special token balance
        address receiptToken = integration.contractAddress;
        tokenBalances[msg.sender][receiptToken] = tokenBalances[msg.sender][receiptToken].add(receiptTokenAmount);
        userTokens[msg.sender].add(receiptToken);
        
        // Update last call time
        integration.lastCallTime = block.timestamp;
        
        emit DeFiIntegrationCalled(integrationId, bytes4(keccak256("deposit(address,uint256)")), 0);
        
        return receiptTokenAmount;
    }
    
    // Withdraw from lending protocol
    function withdrawFromLendingProtocol(
        uint256 integrationId,
        address token,
        uint256 amount
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (uint256)
    {
        require(integrationId > 0 && integrationId <= _defiIntegrationIdCounter.current(), "Invalid integration ID");
        
        DeFiIntegration storage integration = defiIntegrations[integrationId];
        require(integration.isActive, "Integration not active");
        require(integration.protocolType == DeFiProtocolType.LENDING, "Not a lending integration");
        
        // Get receipt token
        address receiptToken = integration.contractAddress;
        
        // Check if user has enough receipt tokens
        require(tokenBalances[msg.sender][receiptToken] >= amount, "Insufficient receipt token balance");
        
        // Construct withdraw function call data
        bytes memory withdrawData = abi.encodeWithSignature(
            "withdraw(address,uint256)",
            token,
            amount
        );
        
        // Deduct receipt tokens from user balance
        tokenBalances[msg.sender][receiptToken] = tokenBalances[msg.sender][receiptToken].sub(amount);
        
        if (tokenBalances[msg.sender][receiptToken] == 0) {
            userTokens[msg.sender].remove(receiptToken);
        }
        
        // Call lending protocol function
        (bool success, bytes memory result) = integration.contractAddress.call(withdrawData);
        require(success, "Withdrawal failed");
        
        // Parse result to get token amount
        uint256 tokenAmount = abi.decode(result, (uint256));
        
        // Add tokens to user balance
        tokenBalances[msg.sender][token] = tokenBalances[msg.sender][token].add(tokenAmount);
        userTokens[msg.sender].add(token);
        
        // Update last call time
        integration.lastCallTime = block.timestamp;
        
        // Calculate and charge platform fee
        uint256 platformFeeAmount = (tokenAmount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 userAmount = tokenAmount.sub(platformFeeAmount);
        
        // Update balances to account for fee
        tokenBalances[msg.sender][token] = tokenBalances[msg.sender][token].sub(platformFeeAmount);
        tokenBalances[feeCollector][token] = tokenBalances[feeCollector][token].add(platformFeeAmount);
        userTokens[feeCollector].add(token);
        
        emit DeFiIntegrationCalled(integrationId, bytes4(keccak256("withdraw(address,uint256)")), 0);
        
        return userAmount;
    }
    
    // Get price from oracle
    function getPriceFromOracle(
        uint256 integrationId,
        address token
    ) 
        external 
        view 
        returns (uint256)
    {
        require(integrationId > 0 && integrationId <= _defiIntegrationIdCounter.current(), "Invalid integration ID");
        
        DeFiIntegration storage integration = defiIntegrations[integrationId];
        require(integration.isActive, "Integration not active");
        require(integration.protocolType == DeFiProtocolType.OTHER, "Not an oracle integration");
        
        // Construct price function call data
        bytes memory priceData = abi.encodeWithSignature(
            "getPrice(address)",
            token
        );
        
        // Call oracle function
        (bool success, bytes memory result) = integration.contractAddress.staticcall(priceData);
        require(success, "Oracle call failed");
        
        // Parse result to get price
        uint256 price = abi.decode(result, (uint256));
        
        return price;
    }
    
    // Create cross-chain token swap
    function createCrossChainSwap(
        uint256 targetChainId,
        address localToken,
        uint256 localAmount,
        address targetToken,
        uint256 targetAmount,
        uint256 deadline
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (uint256)
    {
        require(targetChainId != block.chainid, "Cannot swap on same chain");
        require(localToken != address(0), "Invalid local token");
        require(targetToken != address(0), "Invalid target token");
        require(localAmount > 0, "Local amount must be greater than 0");
        require(targetAmount > 0, "Target amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        // Check if user has enough tokens
        require(tokenBalances[msg.sender][localToken] >= localAmount, "Insufficient token balance");
        
        // Calculate fee for cross-chain swap
        uint256 swapFee = 0.002 ether;
        require(msg.value >= swapFee, "Insufficient fee");
        
        // Lock local tokens
        tokenBalances[msg.sender][localToken] = tokenBalances[msg.sender][localToken].sub(localAmount);
        
        // Create swap message
        bytes memory swapData = abi.encodeWithSignature(
            "executeCrossChainSwap(address,address,uint256,uint256,address)",
            localToken,
            targetToken,
            localAmount,
            targetAmount,
            msg.sender
        );
        
        // Increment message ID counter
        _messageIdCounter.increment();
        uint256 newMessageId = _messageIdCounter.current();
        
        // Create message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                newMessageId,
                msg.sender,
                block.chainid,
                targetChainId,
                swapData,
                deadline
            )
        );
        
        // Create new cross-chain message
        CrossChainMessage storage newMessage = crossChainMessages[newMessageId];
        newMessage.id = newMessageId;
        newMessage.sender = msg.sender;
        newMessage.sourceChainId = block.chainid;
        newMessage.targetChainId = targetChainId;
        newMessage.message = swapData;
        newMessage.status = CrossChainMessageStatus.SENT;
        newMessage.timestamp = block.timestamp;
        newMessage.fee = swapFee;
        newMessage.hash = messageHash;
        
        // Transfer fee to fee collector
        userBalances[feeCollector] = userBalances[feeCollector].add(swapFee);
        
        // Refund excess payment
        if (msg.value > swapFee) {
            (bool success, ) = msg.sender.call{value: msg.value - swapFee}("");
            require(success, "Refund failed");
        }
        
        emit CrossChainMessageSent(newMessageId, msg.sender, block.chainid, targetChainId);
        emit FeePaid(msg.sender, swapFee, "Cross-Chain Swap");
        
        return newMessageId;
    }
    
    // Execute cross-chain swap (called by receiveCrossChainMessage)
    function executeCrossChainSwap(
        address sourceToken,
        address targetToken,
        uint256 sourceAmount,
        uint256 targetAmount,
        address recipient
    ) 
        external 
        onlyOwner 
    {
        require(targetToken != address(0), "Invalid target token");
        require(recipient != address(0), "Invalid recipient address");
        require(targetAmount > 0, "Target amount must be greater than 0");
        
        // Check if contract has enough target tokens
        require(
            IERC20(targetToken).balanceOf(address(this)) >= targetAmount, 
            "Insufficient contract token balance"
        );
        
        // Register recipient if not already registered
        if (!isRegistered[recipient]) {
            // Create basic profile
            userProfiles[recipient].name = "Cross-Chain User";
            userProfiles[recipient].registrationTime = block.timestamp;
            userProfiles[recipient].lastActivityTime = block.timestamp;
            isRegistered[recipient] = true;
        }
        
        // Credit target tokens to recipient
        tokenBalances[recipient][targetToken] = tokenBalances[recipient][targetToken].add(targetAmount);
        userTokens[recipient].add(targetToken);
        
        // Emit events
        emit TokenDeposited(recipient, targetToken, targetAmount);
    }
    
    // ==================== ORACLE INTEGRATION FUNCTIONS ====================
    
    // Structure for oracle data
    struct OracleData {
        uint256 timestamp;
        uint256 value;
        bytes32 dataHash;
        address provider;
        bool isVerified;
    }
    
    // Mapping for oracle data
    mapping(bytes32 => OracleData) public oracleData;
    mapping(address => bool) public trustedOracles;
    
    // Event for oracle data
    event OracleDataProvided(bytes32 indexed dataId, address indexed provider, uint256 timestamp, uint256 value);
    event OracleDataVerified(bytes32 indexed dataId, bool isVerified);
    
    // Add trusted oracle
    function addTrustedOracle(address oracle) 
        external 
        onlyOwner 
    {
        require(oracle != address(0), "Invalid oracle address");
        trustedOracles[oracle] = true;
    }
    
    // Remove trusted oracle
    function removeTrustedOracle(address oracle) 
        external 
        onlyOwner 
    {
        trustedOracles[oracle] = false;
    }
    
    // Provide oracle data
    function provideOracleData(
        bytes32 dataId,
        uint256 value,
        bytes memory signature
    ) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(trustedOracles[msg.sender], "Not a trusted oracle");
        
        // Verify signature
        bytes32 dataHash = keccak256(abi.encodePacked(dataId, value, block.timestamp));
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        address signer = messageHash.recover(signature);
        
        require(signer == msg.sender, "Invalid signature");
        
        // Store oracle data
        OracleData storage data = oracleData[dataId];
        data.timestamp = block.timestamp;
        data.value = value;
        data.dataHash = dataHash;
        data.provider = msg.sender;
        data.isVerified = true;
        
        emit OracleDataProvided(dataId, msg.sender, block.timestamp, value);
        emit OracleDataVerified(dataId, true);
    }
    
    // Get oracle data
    function getOracleData(bytes32 dataId) 
        external 
        view 
        returns (
            uint256 timestamp,
            uint256 value,
            address provider,
            bool isVerified
        ) 
    {
        OracleData storage data = oracleData[dataId];
        
        return (
            data.timestamp,
            data.value,
            data.provider,
            data.isVerified
        );
    }
    
    // Verify oracle data freshness
    function isOracleDataFresh(bytes32 dataId, uint256 maxAge) 
        external 
        view 
        returns (bool) 
    {
        OracleData storage data = oracleData[dataId];
        
        if (!data.isVerified) {
            return false;
        }
        
        return (block.timestamp - data.timestamp) <= maxAge;
    }
    
    // ==================== BLOCKCHAIN INTEROPERABILITY FUNCTIONS ====================
    
    // Structure for blockchain bridge
    struct BlockchainBridge {
        uint256 id;
        string name;
        uint256 sourceChainId;
        uint256 targetChainId;
        address bridgeAddress;
        bool isActive;
        uint256 creationTime;
        uint256 fee;
    }
    
    // Mapping for blockchain bridges
    mapping(uint256 => BlockchainBridge) public blockchainBridges;
    mapping(uint256 => mapping(uint256 => uint256)) public chainToBridgeId; // sourceChainId => targetChainId => bridgeId
    
    // Counter for blockchain bridges
    Counters.Counter private _bridgeIdCounter;
    
    // Event for blockchain bridge
    event BlockchainBridgeAdded(uint256 indexed bridgeId, string name, uint256 sourceChainId, uint256 targetChainId);
    event BlockchainBridgeUpdated(uint256 indexed bridgeId, bool isActive);
    event AssetBridged(uint256 indexed bridgeId, address indexed sender, address indexed recipient, uint256 amount);
    
    // Add blockchain bridge
    function addBlockchainBridge(
        string memory name,
        uint256 sourceChainId,
        uint256 targetChainId,
        address bridgeAddress,
        uint256 fee
    ) 
        external 
        onlyOwner 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bridgeAddress != address(0), "Invalid bridge address");
        require(sourceChainId > 0, "Invalid source chain ID");
        require(targetChainId > 0, "Invalid target chain ID");
        require(sourceChainId != targetChainId, "Source and target chains must be different");
        
        // Increment bridge ID counter
        _bridgeIdCounter.increment();
        uint256 newBridgeId = _bridgeIdCounter.current();
        
        // Create new blockchain bridge
        BlockchainBridge storage newBridge = blockchainBridges[newBridgeId];
        newBridge.id = newBridgeId;
        newBridge.name = name;
        newBridge.sourceChainId = sourceChainId;
        newBridge.targetChainId = targetChainId;
        newBridge.bridgeAddress = bridgeAddress;
        newBridge.isActive = true;
        newBridge.creationTime = block.timestamp;
        newBridge.fee = fee;
        
        // Map chain pair to bridge ID
        chainToBridgeId[sourceChainId][targetChainId] = newBridgeId;
        
        emit BlockchainBridgeAdded(newBridgeId, name, sourceChainId, targetChainId);
    }
    
    // Update blockchain bridge status
    function updateBlockchainBridgeStatus(uint256 bridgeId, bool isActive) 
        external 
        onlyOwner 
    {
        require(bridgeId > 0 && bridgeId <= _bridgeIdCounter.current(), "Invalid bridge ID");
        
        BlockchainBridge storage bridge = blockchainBridges[bridgeId];
        bridge.isActive = isActive;
        
        emit BlockchainBridgeUpdated(bridgeId, isActive);
    }
    
    // Bridge assets to another blockchain
    function bridgeAssets(
        uint256 bridgeId,
        address token,
        uint256 amount,
        address recipient,
        bytes memory data
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bridgeId > 0 && bridgeId <= _bridgeIdCounter.current(), "Invalid bridge ID");
        
        BlockchainBridge storage bridge = blockchainBridges[bridgeId];
        require(bridge.isActive, "Bridge not active");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(recipient != address(0), "Invalid recipient address");
        
        // Check if current chain matches source chain
        require(block.chainid == bridge.sourceChainId, "Current chain does not match source chain");
        
        // Check if user has enough tokens
        require(tokenBalances[msg.sender][token] >= amount, "Insufficient token balance");
        
        // Calculate bridge fee
        uint256 bridgeFee = bridge.fee;
        require(msg.value >= bridgeFee, "Insufficient fee");
        
        // Deduct tokens from user balance
        tokenBalances[msg.sender][token] = tokenBalances[msg.sender][token].sub(amount);
        
        if (tokenBalances[msg.sender][token] == 0) {
            userTokens[msg.sender].remove(token);
        }
        
        // Prepare data for bridge
        bytes memory bridgeData = abi.encodeWithSignature(
            "bridgeToken(address,uint256,address,bytes)",
            token,
            amount,
            recipient,
            data
        );
        
        // Transfer token to bridge contract
        IERC20(token).transfer(bridge.bridgeAddress, amount);
        
        // Call bridge contract
        (bool success, ) = bridge.bridgeAddress.call{value: bridgeFee}(bridgeData);
        require(success, "Bridge call failed");
        
        // Refund excess payment
        if (msg.value > bridgeFee) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - bridgeFee}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit AssetBridged(bridgeId, msg.sender, recipient, amount);
    }
    
    // Receive bridged assets from another blockchain
    function receiveBridgedAssets(
        uint256 sourceChainId,
        address token,
        uint256 amount,
        address recipient,
        bytes memory data
    ) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        // Only allow calls from active bridges
        uint256 bridgeId = chainToBridgeId[sourceChainId][block.chainid];
        require(bridgeId > 0, "No bridge configured for chain pair");
        require(blockchainBridges[bridgeId].isActive, "Bridge not active");
        require(msg.sender == blockchainBridges[bridgeId].bridgeAddress, "Only bridge can call this function");
        
        // Register recipient if not already registered
        if (!isRegistered[recipient]) {
            // Create basic profile
            userProfiles[recipient].name = "Bridge User";
            userProfiles[recipient].registrationTime = block.timestamp;
            userProfiles[recipient].lastActivityTime = block.timestamp;
            isRegistered[recipient] = true;
        }
        
        // Credit tokens to recipient
        tokenBalances[recipient][token] = tokenBalances[recipient][token].add(amount);
        userTokens[recipient].add(token);
        
        // Process additional data if needed
        if (data.length > 0) {
            // Execute data as a function call
            (bool success, ) = address(this).call(data);
            // Ignore failure, bridge should still work even if additional logic fails
            if (!success) {
                emit SecurityBreach(address(0), "Bridged asset data execution failed", block.timestamp);
            }
        }
        
        emit AssetBridged(bridgeId, msg.sender, recipient, amount);
    }
    
    // Get blockchain bridge details
    function getBlockchainBridgeDetails(uint256 bridgeId) 
        external 
        view 
        returns (
            string memory name,
            uint256 sourceChainId,
            uint256 targetChainId,
            address bridgeAddress,
            bool isActive,
            uint256 fee
        ) 
    {
        require(bridgeId > 0 && bridgeId <= _bridgeIdCounter.current(), "Invalid bridge ID");
        
        BlockchainBridge storage bridge = blockchainBridges[bridgeId];
        
        return (
            bridge.name,
            bridge.sourceChainId,
            bridge.targetChainId,
            bridge.bridgeAddress,
            bridge.isActive,
            bridge.fee
        );
    }
    
    // Get bridge ID for chain pair
    function getBridgeIdForChainPair(uint256 sourceChainId, uint256 targetChainId) 
        external 
        view 
        returns (uint256) 
    {
        return chainToBridgeId[sourceChainId][targetChainId];
    }
    
    // Get all active bridges
    function getActiveBridges() 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count active bridges
        for (uint256 i = 1; i <= _bridgeIdCounter.current(); i++) {
            if (blockchainBridges[i].isActive) {
                count++;
            }
        }
        
        // Create array to hold bridge IDs
        uint256[] memory activeBridges = new uint256[](count);
        uint256 index = 0;
        
        // Fill array
        for (uint256 i = 1; i <= _bridgeIdCounter.current(); i++) {
            if (blockchainBridges[i].isActive) {
                activeBridges[index] = i;
                index++;
            }
        }
        
        return activeBridges;
    }
    
    // Get bridges for a specific chain
    function getBridgesForChain(uint256 chainId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count bridges for the specified chain
        for (uint256 i = 1; i <= _bridgeIdCounter.current(); i++) {
            if (
                blockchainBridges[i].isActive && 
                (blockchainBridges[i].sourceChainId == chainId || blockchainBridges[i].targetChainId == chainId)
            ) {
                count++;
            }
        }
        
        // Create array to hold bridge IDs
        uint256[] memory chainBridges = new uint256[](count);
        uint256 index = 0;
        
        // Fill array
        for (uint256 i = 1; i <= _bridgeIdCounter.current(); i++) {
            if (
                blockchainBridges[i].isActive && 
                (blockchainBridges[i].sourceChainId == chainId || blockchainBridges[i].targetChainId == chainId)
            ) {
                chainBridges[index] = i;
                index++;
            }
        }
        
        return chainBridges;
    }
    
    // ==================== MONAD-SPECIFIC FUNCTIONS ====================
    
    // Structure for Monad network status
    struct MonadNetworkStatus {
        uint256 blockHeight;
        uint256 gasPrice;
        uint256 transactionCount;
        uint256 activeValidators;
        uint256 totalStaked;
        uint256 timestamp;
    }
    
    // Current Monad network status
    MonadNetworkStatus public monadNetworkStatus;
    
    // Event for Monad network status
    event MonadNetworkStatusUpdated(uint256 blockHeight, uint256 gasPrice, uint256 activeValidators);
    
    // Update Monad network status
    function updateMonadNetworkStatus(
        uint256 blockHeight,
        uint256 gasPrice,
        uint256 transactionCount,
        uint256 activeValidators,
        uint256 totalStaked
    ) 
        external 
        onlyOwner 
    {
        monadNetworkStatus.blockHeight = blockHeight;
        monadNetworkStatus.gasPrice = gasPrice;
        monadNetworkStatus.transactionCount = transactionCount;
        monadNetworkStatus.activeValidators = activeValidators;
        monadNetworkStatus.totalStaked = totalStaked;
        monadNetworkStatus.timestamp = block.timestamp;
        
        emit MonadNetworkStatusUpdated(blockHeight, gasPrice, activeValidators);
    }
    
    // Get Monad network status
    function getMonadNetworkStatus() 
        external 
        view 
        returns (
            uint256 blockHeight,
            uint256 gasPrice,
            uint256 transactionCount,
            uint256 activeValidators,
            uint256 totalStaked,
            uint256 timestamp
        ) 
    {
        return (
            monadNetworkStatus.blockHeight,
            monadNetworkStatus.gasPrice,
            monadNetworkStatus.transactionCount,
            monadNetworkStatus.activeValidators,
            monadNetworkStatus.totalStaked,
            monadNetworkStatus.timestamp
        );
    }
    
    // Batch execute transactions
    function batchExecuteTransactions(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) 
        external 
        payable
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(targets.length == values.length, "Arrays length mismatch");
        require(values.length == datas.length, "Arrays length mismatch");
        
        uint256 totalValue = 0;
        for (uint256 i = 0; i < values.length; i++) {
            totalValue = totalValue.add(values[i]);
        }
        
        require(msg.value >= totalValue, "Insufficient value provided");
        
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{value: values[i]}(datas[i]);
            require(success, "Transaction execution failed");
        }
        
        // Refund excess value
        if (msg.value > totalValue) {
            (bool success, ) = msg.sender.call{value: msg.value - totalValue}("");
            require(success, "Refund failed");
        }
    }
    
    // Get chain ID
    function getChainId() 
        external 
        view 
        returns (uint256) 
    {
        return block.chainid;
    }

// END OF PART 7/12 - CONTINUE TO PART 8/12
// SPDX-License-Identifier: MIT
// PART 8.1/12 - MonadEcosystemHubV1
// Stats & Analytics Advanced Functions
// Continues from PART 7/12

// CONTINUED FROM PART 7/12

    // ==================== STATS & ANALYTICS ADVANCED FUNCTIONS ====================
    
    // Structure for system analytics
    struct SystemAnalytics {
        uint256 timestamp;
        uint256 totalUsers;
        uint256 totalResources;
        uint256 totalExchanges;
        uint256 totalProposals;
        uint256 totalGames;
        uint256 totalDatasets;
        uint256 totalTransactions;
        uint256 activeUsersLast24h;
        uint256 activeUsersLast7d;
        uint256 totalValueLocked;
    }
    
    // System analytics snapshots
    mapping(uint256 => SystemAnalytics) public analyticsSnapshots;
    uint256 public lastSnapshotTimestamp;
    uint256 public snapshotInterval = 1 days;
    
    // Event for system analytics snapshot
    event AnalyticsSnapshotCreated(uint256 timestamp, uint256 totalUsers, uint256 totalValueLocked);
    
    // Create system analytics snapshot
    function createAnalyticsSnapshot() 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(block.timestamp >= lastSnapshotTimestamp + snapshotInterval, "Snapshot interval not reached");
        
        // Calculate active users in last 24 hours
        uint256 activeUsersLast24h = 0;
        // Calculate active users in last 7 days
        uint256 activeUsersLast7d = 0;
        
        // Sample 1000 addresses to estimate active users
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (isRegistered[user]) {
                if (block.timestamp - userProfiles[user].lastActivityTime <= 1 days) {
                    activeUsersLast24h++;
                }
                
                if (block.timestamp - userProfiles[user].lastActivityTime <= 7 days) {
                    activeUsersLast7d++;
                }
            }
        }
        
        // Calculate total value locked
        uint256 totalValueLocked = address(this).balance;
        
        // Create snapshot
        SystemAnalytics storage snapshot = analyticsSnapshots[block.timestamp];
        snapshot.timestamp = block.timestamp;
        snapshot.totalResources = _resourceIdCounter.current();
        snapshot.totalExchanges = _exchangeIdCounter.current();
        snapshot.totalProposals = _proposalIdCounter.current();
        snapshot.totalGames = _gameIdCounter.current();
        snapshot.totalDatasets = _datasetIdCounter.current();
        snapshot.totalTransactions = block.number; // Simplified - in practice we would track actual tx count
        snapshot.activeUsersLast24h = activeUsersLast24h;
        snapshot.activeUsersLast7d = activeUsersLast7d;
        snapshot.totalValueLocked = totalValueLocked;
        
        // Update last snapshot timestamp
        lastSnapshotTimestamp = block.timestamp;
        
        emit AnalyticsSnapshotCreated(block.timestamp, snapshot.totalUsers, totalValueLocked);
    }
    
    // Get latest system analytics snapshot
    function getLatestAnalyticsSnapshot() 
        external 
        view 
        returns (
            uint256 timestamp,
            uint256 totalUsers,
            uint256 totalResources,
            uint256 totalExchanges,
            uint256 totalProposals,
            uint256 totalGames,
            uint256 totalDatasets,
            uint256 totalTransactions,
            uint256 activeUsersLast24h,
            uint256 activeUsersLast7d,
            uint256 totalValueLocked
        ) 
    {
        SystemAnalytics storage snapshot = analyticsSnapshots[lastSnapshotTimestamp];
        
        return (
            snapshot.timestamp,
            snapshot.totalUsers,
            snapshot.totalResources,
            snapshot.totalExchanges,
            snapshot.totalProposals,
            snapshot.totalGames,
            snapshot.totalDatasets,
            snapshot.totalTransactions,
            snapshot.activeUsersLast24h,
            snapshot.activeUsersLast7d,
            snapshot.totalValueLocked
        );
    }
    
    // Get system analytics snapshot for a specific timestamp
    function getAnalyticsSnapshotAt(uint256 timestamp) 
        external 
        view 
        returns (
            uint256 totalUsers,
            uint256 totalResources,
            uint256 totalExchanges,
            uint256 totalProposals,
            uint256 totalGames,
            uint256 totalDatasets,
            uint256 totalTransactions,
            uint256 activeUsersLast24h,
            uint256 activeUsersLast7d,
            uint256 totalValueLocked
        ) 
    {
        SystemAnalytics storage snapshot = analyticsSnapshots[timestamp];
        
        return (
            snapshot.totalUsers,
            snapshot.totalResources,
            snapshot.totalExchanges,
            snapshot.totalProposals,
            snapshot.totalGames,
            snapshot.totalDatasets,
            snapshot.totalTransactions,
            snapshot.activeUsersLast24h,
            snapshot.activeUsersLast7d,
            snapshot.totalValueLocked
        );
    }
    
    // Set snapshot interval
    function setSnapshotInterval(uint256 interval) 
        external 
        onlyOwner 
    {
        require(interval >= 1 hours && interval <= 30 days, "Invalid interval");
        snapshotInterval = interval;
    }
    
    // Calculate system growth metrics
    function calculateSystemGrowthMetrics(uint256 fromTimestamp, uint256 toTimestamp) 
        external 
        view 
        returns (
            int256 userGrowth,
            int256 resourceGrowth,
            int256 exchangeGrowth,
            int256 proposalGrowth,
            int256 gameGrowth,
            int256 datasetGrowth,
            int256 tvlGrowth
        ) 
    {
        require(fromTimestamp < toTimestamp, "Invalid time range");
        require(analyticsSnapshots[fromTimestamp].timestamp > 0, "No snapshot at fromTimestamp");
        require(analyticsSnapshots[toTimestamp].timestamp > 0, "No snapshot at toTimestamp");
        
        SystemAnalytics storage fromSnapshot = analyticsSnapshots[fromTimestamp];
        SystemAnalytics storage toSnapshot = analyticsSnapshots[toTimestamp];
        
        // Calculate growth metrics
        userGrowth = int256(toSnapshot.totalUsers) - int256(fromSnapshot.totalUsers);
        resourceGrowth = int256(toSnapshot.totalResources) - int256(fromSnapshot.totalResources);
        exchangeGrowth = int256(toSnapshot.totalExchanges) - int256(fromSnapshot.totalExchanges);
        proposalGrowth = int256(toSnapshot.totalProposals) - int256(fromSnapshot.totalProposals);
        gameGrowth = int256(toSnapshot.totalGames) - int256(fromSnapshot.totalGames);
        datasetGrowth = int256(toSnapshot.totalDatasets) - int256(fromSnapshot.totalDatasets);
        tvlGrowth = int256(toSnapshot.totalValueLocked) - int256(fromSnapshot.totalValueLocked);
        
        return (
            userGrowth,
            resourceGrowth,
            exchangeGrowth,
            proposalGrowth,
            gameGrowth,
            datasetGrowth,
            tvlGrowth
        );
    }
    
    // Structure for user activity metrics
    struct UserActivityMetrics {
        uint256 timestamp;
        uint256 userId;
        uint256 resourcesCreated;
        uint256 resourcesUsed;
        uint256 exchangesCreated;
        uint256 exchangesParticipated;
        uint256 proposalsCreated;
        uint256 proposalsVoted;
        uint256 gamesCreated;
        uint256 gamesPlayed;
        uint256 datasetsCreated;
        uint256 datasetsAccessed;
        uint256 totalActions;
        uint256 reputation;
    }
    
    // Mapping for user activity metrics
    mapping(address => mapping(uint256 => UserActivityMetrics)) public userActivityMetrics; // user => timestamp => metrics
    mapping(address => uint256) public lastUserMetricsTimestamp;
    
    // Event for user activity metrics
    event UserActivityMetricsUpdated(address indexed user, uint256 timestamp, uint256 totalActions);
    
    // Update user activity metrics
    function updateUserActivityMetrics(address user) 
        public 
        whenNotPaused 
        onlyOwner 
    {
        require(isRegistered[user], "User not registered");
        require(block.timestamp >= lastUserMetricsTimestamp[user] + 1 days, "Metrics update interval not reached");
        
        // Create new user activity metrics
        UserActivityMetrics storage metrics = userActivityMetrics[user][block.timestamp];
        metrics.timestamp = block.timestamp;
        metrics.userId = uint256(uint160(user));
        
        // Calculate resources created
        metrics.resourcesCreated = ownedResources[user].length();
        
        // Calculate resources used (simplified)
        metrics.resourcesUsed = 0;
        for (uint256 i = 1; i <= _resourceIdCounter.current() && i <= 100; i++) {
            if (resourceAllocation[i][user] > 0) {
                metrics.resourcesUsed++;
            }
        }
        
        // Calculate exchanges created and participated
        metrics.exchangesCreated = 0;
        metrics.exchangesParticipated = 0;
        uint256[] memory userExchangeIds = getUserExchanges(user);
        for (uint256 i = 0; i < userExchangeIds.length && i < 100; i++) {
            uint256 exchangeId = userExchangeIds[i];
            if (exchanges[exchangeId].creator == user) {
                metrics.exchangesCreated++;
            } else {
                metrics.exchangesParticipated++;
            }
        }
        
        // Calculate proposals created and voted
        metrics.proposalsCreated = 0;
        for (uint256 i = 1; i <= _proposalIdCounter.current() && i <= 100; i++) {
            if (proposals[i].proposer == user) {
                metrics.proposalsCreated++;
            }
        }
        metrics.proposalsVoted = userVotedProposals[user].length();
        
        // Calculate games created and played
        metrics.gamesCreated = 0;
        metrics.gamesPlayed = 0;
        uint256[] memory userGameIds = getUserGames(user);
        for (uint256 i = 0; i < userGameIds.length && i < 100; i++) {
            uint256 gameId = userGameIds[i];
            if (games[gameId].creator == user) {
                metrics.gamesCreated++;
            } else {
                metrics.gamesPlayed++;
            }
        }
        
        // Calculate datasets created and accessed
        metrics.datasetsCreated = ownedDatasets[user].length();
        metrics.datasetsAccessed = 0;
        for (uint256 i = 1; i <= _datasetIdCounter.current() && i <= 100; i++) {
            if (datasetAccess[i][user] && datasets[i].owner != user) {
                metrics.datasetsAccessed++;
            }
        }
        
        // Calculate total actions
        metrics.totalActions = metrics.resourcesCreated + 
                              metrics.resourcesUsed + 
                              metrics.exchangesCreated + 
                              metrics.exchangesParticipated + 
                              metrics.proposalsCreated + 
                              metrics.proposalsVoted + 
                              metrics.gamesCreated + 
                              metrics.gamesPlayed + 
                              metrics.datasetsCreated + 
                              metrics.datasetsAccessed;
        
        // Store reputation
        metrics.reputation = userReputation[user];
        
        // Update last metrics timestamp
        lastUserMetricsTimestamp[user] = block.timestamp;
        
        emit UserActivityMetricsUpdated(user, block.timestamp, metrics.totalActions);
    }
    
    // Get latest user activity metrics
    function getLatestUserActivityMetrics(address user) 
        external 
        view 
        returns (
            uint256 timestamp,
            uint256 resourcesCreated,
            uint256 resourcesUsed,
            uint256 exchangesCreated,
            uint256 exchangesParticipated,
            uint256 proposalsCreated,
            uint256 proposalsVoted,
            uint256 gamesCreated,
            uint256 gamesPlayed,
            uint256 datasetsCreated,
            uint256 datasetsAccessed,
            uint256 totalActions,
            uint256 reputation
        ) 
    {
        uint256 metricsTimestamp = lastUserMetricsTimestamp[user];
        UserActivityMetrics storage metrics = userActivityMetrics[user][metricsTimestamp];
        
        return (
            metrics.timestamp,
            metrics.resourcesCreated,
            metrics.resourcesUsed,
            metrics.exchangesCreated,
            metrics.exchangesParticipated,
            metrics.proposalsCreated,
            metrics.proposalsVoted,
            metrics.gamesCreated,
            metrics.gamesPlayed,
            metrics.datasetsCreated,
            metrics.datasetsAccessed,
            metrics.totalActions,
            metrics.reputation
        );
    }
    
    // Get user activity metrics at specific timestamp
    function getUserActivityMetricsAt(address user, uint256 timestamp) 
        external 
        view 
        returns (
            uint256 resourcesCreated,
            uint256 resourcesUsed,
            uint256 exchangesCreated,
            uint256 exchangesParticipated,
            uint256 proposalsCreated,
            uint256 proposalsVoted,
            uint256 gamesCreated,
            uint256 gamesPlayed,
            uint256 datasetsCreated,
            uint256 datasetsAccessed,
            uint256 totalActions,
            uint256 reputation
        ) 
    {
        UserActivityMetrics storage metrics = userActivityMetrics[user][timestamp];
        
        return (
            metrics.resourcesCreated,
            metrics.resourcesUsed,
            metrics.exchangesCreated,
            metrics.exchangesParticipated,
            metrics.proposalsCreated,
            metrics.proposalsVoted,
            metrics.gamesCreated,
            metrics.gamesPlayed,
            metrics.datasetsCreated,
            metrics.datasetsAccessed,
            metrics.totalActions,
            metrics.reputation
        );
    }
    // CONTINUED FROM PART 8.1/12

    // ==================== REPORTING & VISUALIZATION FUNCTIONS ====================
    
    // Structure for dashboard data
    struct DashboardData {
        uint256 timestamp;
        uint256 userCount;
        uint256 activeUsers;
        uint256 resourceCount;
        uint256 exchangeCount;
        uint256 proposalCount;
        uint256 gameCount;
        uint256 datasetCount;
        uint256 totalValueLocked;
        int256 userGrowthRate;
        int256 tvlGrowthRate;
        uint256 engagementRate;
    }
    
    // Store dashboard data snapshots
    mapping(uint256 => DashboardData) public dashboardDataSnapshots;
    uint256[] public dashboardSnapshotTimestamps;
    
    // Event for dashboard data updates
    event DashboardDataUpdated(uint256 timestamp, uint256 userCount, uint256 activeUsers);
    
    // Update dashboard data
    function updateDashboardData() 
        external 
        whenNotPaused 
        onlyOwner 
    {
        // Calculate active users (users with activity in the last 7 days)
        uint256 activeUsers = 0;
        uint256 totalEngagement = 0;
        
        // Sample 1000 addresses to estimate active users and engagement
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (isRegistered[user]) {
                if (block.timestamp - userProfiles[user].lastActivityTime <= 7 days) {
                    activeUsers++;
                    totalEngagement += calculateUserActivityScore(user);
                }
            }
        }
        
        // Calculate growth rates based on previous snapshot
        int256 userGrowthRate = 0;
        int256 tvlGrowthRate = 0;
        
        if (dashboardSnapshotTimestamps.length > 0) {
            uint256 prevTimestamp = dashboardSnapshotTimestamps[dashboardSnapshotTimestamps.length - 1];
            DashboardData storage prevSnapshot = dashboardDataSnapshots[prevTimestamp];
            
            if (prevSnapshot.userCount > 0) {
                userGrowthRate = (int256(getTotalUsersCount()) - int256(prevSnapshot.userCount)) * 10000 / int256(prevSnapshot.userCount);
            }
            
            if (prevSnapshot.totalValueLocked > 0) {
                tvlGrowthRate = (int256(address(this).balance) - int256(prevSnapshot.totalValueLocked)) * 10000 / int256(prevSnapshot.totalValueLocked);
            }
        }
        
        // Calculate engagement rate (average activity score per active user)
        uint256 engagementRate = activeUsers > 0 ? totalEngagement / activeUsers : 0;
        
        // Create new dashboard data snapshot
        DashboardData storage newSnapshot = dashboardDataSnapshots[block.timestamp];
        newSnapshot.timestamp = block.timestamp;
        newSnapshot.userCount = getTotalUsersCount();
        newSnapshot.activeUsers = activeUsers;
        newSnapshot.resourceCount = _resourceIdCounter.current();
        newSnapshot.exchangeCount = _exchangeIdCounter.current();
        newSnapshot.proposalCount = _proposalIdCounter.current();
        newSnapshot.gameCount = _gameIdCounter.current();
        newSnapshot.datasetCount = _datasetIdCounter.current();
        newSnapshot.totalValueLocked = address(this).balance;
        newSnapshot.userGrowthRate = userGrowthRate;
        newSnapshot.tvlGrowthRate = tvlGrowthRate;
        newSnapshot.engagementRate = engagementRate;
        
        // Store timestamp
        dashboardSnapshotTimestamps.push(block.timestamp);
        
        emit DashboardDataUpdated(block.timestamp, newSnapshot.userCount, activeUsers);
    }
    
    // Get latest dashboard data
    function getLatestDashboardData() 
        external 
        view 
        returns (
            uint256 timestamp,
            uint256 userCount,
            uint256 activeUsers,
            uint256 resourceCount,
            uint256 exchangeCount,
            uint256 proposalCount,
            uint256 gameCount,
            uint256 datasetCount,
            uint256 totalValueLocked,
            int256 userGrowthRate,
            int256 tvlGrowthRate,
            uint256 engagementRate
        ) 
    {
        require(dashboardSnapshotTimestamps.length > 0, "No dashboard data available");
        
        uint256 latestTimestamp = dashboardSnapshotTimestamps[dashboardSnapshotTimestamps.length - 1];
        DashboardData storage data = dashboardDataSnapshots[latestTimestamp];
        
        return (
            data.timestamp,
            data.userCount,
            data.activeUsers,
            data.resourceCount,
            data.exchangeCount,
            data.proposalCount,
            data.gameCount,
            data.datasetCount,
            data.totalValueLocked,
            data.userGrowthRate,
            data.tvlGrowthRate,
            data.engagementRate
        );
    }
    
    // Get dashboard data for a specific time period
    function getDashboardDataForPeriod(uint256 fromTimestamp, uint256 toTimestamp) 
        external 
        view 
        returns (uint256[] memory timestamps, DashboardData[] memory dataPoints) 
    {
        require(fromTimestamp < toTimestamp, "Invalid time range");
        
        // Count matching snapshots
        uint256 count = 0;
        for (uint256 i = 0; i < dashboardSnapshotTimestamps.length; i++) {
            uint256 timestamp = dashboardSnapshotTimestamps[i];
            if (timestamp >= fromTimestamp && timestamp <= toTimestamp) {
                count++;
            }
        }
        
        // Create arrays to hold result
        timestamps = new uint256[](count);
        dataPoints = new DashboardData[](count);
        
        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < dashboardSnapshotTimestamps.length && index < count; i++) {
            uint256 timestamp = dashboardSnapshotTimestamps[i];
            if (timestamp >= fromTimestamp && timestamp <= toTimestamp) {
                timestamps[index] = timestamp;
                dataPoints[index] = dashboardDataSnapshots[timestamp];
                index++;
            }
        }
        
        return (timestamps, dataPoints);
    }
    
    // Structure for trend analysis
    struct TrendData {
        uint256 startTimestamp;
        uint256 endTimestamp;
        int256 userGrowth;
        int256 resourceGrowth;
        int256 exchangeGrowth;
        int256 proposalGrowth;
        int256 gameGrowth;
        int256 datasetGrowth;
        int256 tvlGrowth;
        int256 engagementChange;
    }
    
    // Generate trend analysis for a specific time period
    function generateTrendAnalysis(uint256 fromTimestamp, uint256 toTimestamp) 
        external 
        view 
        returns (TrendData memory trend) 
    {
        require(fromTimestamp < toTimestamp, "Invalid time range");
        require(dashboardSnapshotTimestamps.length > 0, "No dashboard data available");
        
        // Find closest snapshots to the requested timestamps
        uint256 closestFromTimestamp = 0;
        uint256 closestToTimestamp = 0;
        uint256 fromDiff = type(uint256).max;
        uint256 toDiff = type(uint256).max;
        
        for (uint256 i = 0; i < dashboardSnapshotTimestamps.length; i++) {
            uint256 timestamp = dashboardSnapshotTimestamps[i];
            
            // Find closest from timestamp
            if (timestamp <= fromTimestamp && fromTimestamp - timestamp < fromDiff) {
                closestFromTimestamp = timestamp;
                fromDiff = fromTimestamp - timestamp;
            }
            
            // Find closest to timestamp
            if (timestamp <= toTimestamp && toTimestamp - timestamp < toDiff) {
                closestToTimestamp = timestamp;
                toDiff = toTimestamp - timestamp;
            }
        }
        
        // If no suitable snapshots found, use the earliest and latest available
        if (closestFromTimestamp == 0) {
            closestFromTimestamp = dashboardSnapshotTimestamps[0];
        }
        
        if (closestToTimestamp == 0 || closestFromTimestamp == closestToTimestamp) {
            closestToTimestamp = dashboardSnapshotTimestamps[dashboardSnapshotTimestamps.length - 1];
        }
        
        // Get snapshot data
        DashboardData storage fromData = dashboardDataSnapshots[closestFromTimestamp];
        DashboardData storage toData = dashboardDataSnapshots[closestToTimestamp];
        
        // Calculate growth metrics
        trend.startTimestamp = closestFromTimestamp;
        trend.endTimestamp = closestToTimestamp;
        trend.userGrowth = int256(toData.userCount) - int256(fromData.userCount);
        trend.resourceGrowth = int256(toData.resourceCount) - int256(fromData.resourceCount);
        trend.exchangeGrowth = int256(toData.exchangeCount) - int256(fromData.exchangeCount);
        trend.proposalGrowth = int256(toData.proposalCount) - int256(fromData.proposalCount);
        trend.gameGrowth = int256(toData.gameCount) - int256(fromData.gameCount);
        trend.datasetGrowth = int256(toData.datasetCount) - int256(fromData.datasetCount);
        trend.tvlGrowth = int256(toData.totalValueLocked) - int256(fromData.totalValueLocked);
        trend.engagementChange = int256(toData.engagementRate) - int256(fromData.engagementRate);
        
        return trend;
    }
    
    // Structure for user engagement report
    struct UserEngagementReport {
        uint256 timestamp;
        uint256 totalUsers;
        uint256 newUsers;
        uint256 activeUsersLast24h;
        uint256 activeUsersLast7d;
        uint256 activeUsersLast30d;
        uint256 avgSessionsPerUser;
        uint256 avgActionsPerSession;
        uint256 retentionRate;
        uint256[] topUserIds;
        uint256[] topUserScores;
    }
    
    // Mapping for user engagement reports
    mapping(uint256 => UserEngagementReport) public userEngagementReports;
    uint256[] public reportTimestamps;
    
    // Event for user engagement report
    event UserEngagementReportCreated(uint256 timestamp, uint256 totalUsers, uint256 newUsers);
    
    // Generate user engagement report
    function generateUserEngagementReport() 
        external 
        whenNotPaused 
        onlyOwner 
    {
        // Calculate new users (registered in the last 30 days)
        uint256 newUsers = 0;
        uint256 activeUsersLast24h = 0;
        uint256 activeUsersLast7d = 0;
        uint256 activeUsersLast30d = 0;
        
        // Sample 1000 addresses to estimate user metrics
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (isRegistered[user]) {
                if (block.timestamp - userProfiles[user].registrationTime <= 30 days) {
                    newUsers++;
                }
                
                if (block.timestamp - userProfiles[user].lastActivityTime <= 1 days) {
                    activeUsersLast24h++;
                }
                
                if (block.timestamp - userProfiles[user].lastActivityTime <= 7 days) {
                    activeUsersLast7d++;
                }
                
                if (block.timestamp - userProfiles[user].lastActivityTime <= 30 days) {
                    activeUsersLast30d++;
                }
            }
        }
        
        // Find top users by activity score (simplified)
        address[10] memory topUsers;
        uint256[10] memory topScores;
        
        // Initialize with first 10 registered users
        uint256 topCount = 0;
        for (uint256 i = 0; i < 1000 && topCount < 10; i++) {
            address user = address(uint160(i + 1));
            if (isRegistered[user]) {
                topUsers[topCount] = user;
                topScores[topCount] = calculateUserActivityScore(user);
                topCount++;
            }
        }
        
        // Sort initial top users
        for (uint256 i = 0; i < topCount; i++) {
            for (uint256 j = i + 1; j < topCount; j++) {
                if (topScores[i] < topScores[j]) {
                    // Swap scores
                    uint256 tempScore = topScores[i];
                    topScores[i] = topScores[j];
                    topScores[j] = tempScore;
                    
                    // Swap users
                    address tempUser = topUsers[i];
                    topUsers[i] = topUsers[j];
                    topUsers[j] = tempUser;
                }
            }
        }
        
        // Check remaining users
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(1000 + i + 1));
            if (isRegistered[user]) {
                uint256 score = calculateUserActivityScore(user);
                
                // Check if score is higher than the lowest in our top list
                if (score > topScores[topCount - 1]) {
                    // Replace lowest score with this one
                    topScores[topCount - 1] = score;
                    topUsers[topCount - 1] = user;
                    
                    // Re-sort the list
                    for (uint256 j = 0; j < topCount; j++) {
                        for (uint256 k = j + 1; k < topCount; k++) {
                            if (topScores[j] < topScores[k]) {
                                // Swap scores
                                uint256 tempScore = topScores[j];
                                topScores[j] = topScores[k];
                                topScores[k] = tempScore;
                                
                                // Swap users
                                address tempUser = topUsers[j];
                                topUsers[j] = topUsers[k];
                                topUsers[k] = tempUser;
                            }
                        }
                    }
                }
            }
        }
        
        // Convert top user addresses to IDs
        uint256[] memory topUserIds = new uint256[](topCount);
        uint256[] memory topUserScoresCopy = new uint256[](topCount);
        
        for (uint256 i = 0; i < topCount; i++) {
            topUserIds[i] = uint256(uint160(topUsers[i]));
            topUserScoresCopy[i] = topScores[i];
        }
        
        // Create new report
        UserEngagementReport storage report = userEngagementReports[block.timestamp];
        report.timestamp = block.timestamp;
        report.totalUsers = getTotalUsersCount();
        report.newUsers = newUsers;
        report.activeUsersLast24h = activeUsersLast24h;
        report.activeUsersLast7d = activeUsersLast7d;
        report.activeUsersLast30d = activeUsersLast30d;
        report.avgSessionsPerUser = 5; // Placeholder value
        report.avgActionsPerSession = 8; // Placeholder value
        report.retentionRate = report.activeUsersLast30d * 100 / report.totalUsers;
        report.topUserIds = topUserIds;
        report.topUserScores = topUserScoresCopy;
        
        // Store timestamp
        reportTimestamps.push(block.timestamp);
        
        emit UserEngagementReportCreated(block.timestamp, report.totalUsers, report.newUsers);
    }
    
    // Get latest user engagement report
    function getLatestUserEngagementReport() 
        external 
        view 
        returns (
            uint256 timestamp,
            uint256 totalUsers,
            uint256 newUsers,
            uint256 activeUsersLast24h,
            uint256 activeUsersLast7d,
            uint256 activeUsersLast30d,
            uint256 retentionRate,
            uint256[] memory topUserIds,
            uint256[] memory topUserScores
        ) 
    {
        require(reportTimestamps.length > 0, "No reports available");
        
        uint256 latestTimestamp = reportTimestamps[reportTimestamps.length - 1];
        UserEngagementReport storage report = userEngagementReports[latestTimestamp];
        
        return (
            report.timestamp,
            report.totalUsers,
            report.newUsers,
            report.activeUsersLast24h,
            report.activeUsersLast7d,
            report.activeUsersLast30d,
            report.retentionRate,
            report.topUserIds,
            report.topUserScores
        );
    }
    
    // Structure for transaction volume report
    struct TransactionVolumeReport {
        uint256 timestamp;
        uint256 period; // in days
        uint256 totalTransactions;
        uint256 uniqueUsers;
        uint256 totalValueTransacted;
        uint256 avgTransactionValue;
        uint256 resourceTransactions;
        uint256 exchangeTransactions;
        uint256 governanceTransactions;
        uint256 gameTransactions;
        uint256 dataTransactions;
        uint256 otherTransactions;
    }
    
    // Mapping for transaction volume reports
    mapping(uint256 => TransactionVolumeReport) public transactionReports;
    
    // Event for transaction volume report
    event TransactionReportCreated(uint256 timestamp, uint256 period, uint256 totalTransactions);
    
    // Generate transaction volume report
    function generateTransactionReport(uint256 periodDays) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(periodDays > 0 && periodDays <= 365, "Invalid period");
        
        // This function would typically analyze on-chain data
        // For this contract, we'll simulate some transaction data
        
        // Use timestamps from different counters to estimate transaction counts
        uint256 resourceTx = _resourceIdCounter.current();
        uint256 exchangeTx = _exchangeIdCounter.current();
        uint256 governanceTx = _proposalIdCounter.current() * 3; // Each proposal generates multiple txs
        uint256 gameTx = _gameIdCounter.current() * 5; // Each game generates multiple txs
        uint256 dataTx = _datasetIdCounter.current() * 2; // Each dataset generates multiple txs
        uint256 otherTx = block.number / 10; // Arbitrary other transactions
        
        uint256 totalTx = resourceTx + exchangeTx + governanceTx + gameTx + dataTx + otherTx;
        
        // Estimate unique users
        uint256 uniqueUsers = getTotalUsersCount() / 2; // Assume half of users were active
        
        // Estimate total value transacted (in wei)
        uint256 totalValue = address(this).balance / 10 * periodDays;
        
        // Calculate average transaction value
        uint256 avgValue = totalTx > 0 ? totalValue / totalTx : 0;
        
        // Create new report
        TransactionVolumeReport storage report = transactionReports[block.timestamp];
        report.timestamp = block.timestamp;
        report.period = periodDays;
        report.totalTransactions = totalTx;
        report.uniqueUsers = uniqueUsers;
        report.totalValueTransacted = totalValue;
        report.avgTransactionValue = avgValue;
        report.resourceTransactions = resourceTx;
        report.exchangeTransactions = exchangeTx;
        report.governanceTransactions = governanceTx;
        report.gameTransactions = gameTx;
        report.dataTransactions = dataTx;
        report.otherTransactions = otherTx;
        
        emit TransactionReportCreated(block.timestamp, periodDays, totalTx);
    }
    
    // Get transaction volume report
    function getTransactionReport(uint256 timestamp) 
        external 
        view 
        returns (TransactionVolumeReport memory) 
    {
        return transactionReports[timestamp];
    }
    
    // Structure for category performance metrics
    struct CategoryPerformanceMetrics {
        uint256 timestamp;
        ResourceType bestPerformingResourceType;
        uint256 resourceTypeCount;
        ExchangeType bestPerformingExchangeType;
        uint256 exchangeTypeCount;
        GameType bestPerformingGameType;
        uint256 gameTypeCount;
        DatasetType bestPerformingDatasetType;
        uint256 datasetTypeCount;
        uint256[6] resourceTypeCounts; // One count per ResourceType enum value
        uint256[6] exchangeTypeCounts; // One count per ExchangeType enum value
        uint256[6] gameTypeCounts; // One count per GameType enum value
        uint256[6] datasetTypeCounts; // One count per DatasetType enum value
    }
    
    // Mapping for category performance metrics
    mapping(uint256 => CategoryPerformanceMetrics) public categoryMetrics;
    
    // Event for category performance metrics
    event CategoryMetricsUpdated(uint256 timestamp, ResourceType bestResource, GameType bestGame);
    
    // Generate category performance metrics
    function generateCategoryMetrics() 
        external 
        whenNotPaused 
        onlyOwner 
    {
        // Initialize counters for each type
        uint256[6] memory resourceTypeCounts;
        uint256[6] memory exchangeTypeCounts;
        uint256[6] memory gameTypeCounts;
        uint256[6] memory datasetTypeCounts;
        
        // Count resources by type
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            ResourceType resourceType = resources[i].resourceType;
            resourceTypeCounts[uint256(resourceType)]++;
        }
        
        // Count exchanges by type
        for (uint256 i = 1; i <= _exchangeIdCounter.current(); i++) {
            ExchangeType exchangeType = exchanges[i].exchangeType;
            exchangeTypeCounts[uint256(exchangeType)]++;
        }
        
        // Count games by type
        for (uint256 i = 1; i <= _gameIdCounter.current(); i++) {
            GameType gameType = games[i].gameType;
            gameTypeCounts[uint256(gameType)]++;
        }
        
        // Count datasets by type
        for (uint256 i = 1; i <= _datasetIdCounter.current(); i++) {
            DatasetType datasetType = datasets[i].datasetType;
            datasetTypeCounts[uint256(datasetType)]++;
        }
        
        // Find best performing types
        ResourceType bestResourceType = ResourceType.FUNGIBLE;
        uint256 bestResourceCount = resourceTypeCounts[uint256(ResourceType.FUNGIBLE)];
        
        ExchangeType bestExchangeType = ExchangeType.SELL;
        uint256 bestExchangeCount = exchangeTypeCounts[uint256(ExchangeType.SELL)];
        
        GameType bestGameType = GameType.LOTTERY;
        uint256 bestGameCount = gameTypeCounts[uint256(GameType.LOTTERY)];
        
        DatasetType bestDatasetType = DatasetType.FINANCIAL;
        uint256 bestDatasetCount = datasetTypeCounts[uint256(DatasetType.FINANCIAL)];
        
        // Find best resource type
        for (uint256 i = 0; i < 6; i++) {
            if (resourceTypeCounts[i] > bestResourceCount) {
                bestResourceCount = resourceTypeCounts[i];
                bestResourceType = ResourceType(i);
            }
        }
        
        // Find best exchange type
        for (uint256 i = 0; i < 6; i++) {
            if (exchangeTypeCounts[i] > bestExchangeCount) {
                bestExchangeCount = exchangeTypeCounts[i];
                bestExchangeType = ExchangeType(i);
            }
        }
        
        // Find best game type
        for (uint256 i = 0; i < 6; i++) {
            if (gameTypeCounts[i] > bestGameCount) {
                bestGameCount = gameTypeCounts[i];
                bestGameType = GameType(i);
            }
        }
        
        // Find best dataset type
        for (uint256 i = 0; i < 6; i++) {
            if (datasetTypeCounts[i] > bestDatasetCount) {
                bestDatasetCount = datasetTypeCounts[i];
                bestDatasetType = DatasetType(i);
            }
        }
        
        // Create new metrics
        CategoryPerformanceMetrics storage metrics = categoryMetrics[block.timestamp];
        metrics.timestamp = block.timestamp;
        metrics.bestPerformingResourceType = bestResourceType;
        metrics.resourceTypeCount = bestResourceCount;
        metrics.bestPerformingExchangeType = bestExchangeType;
        metrics.exchangeTypeCount = bestExchangeCount;
        metrics.bestPerformingGameType = bestGameType;
        metrics.gameTypeCount = bestGameCount;
        metrics.bestPerformingDatasetType = bestDatasetType;
        metrics.datasetTypeCount = bestDatasetCount;
        
        // Store all counts
        metrics.resourceTypeCounts = resourceTypeCounts;
        metrics.exchangeTypeCounts = exchangeTypeCounts;
        metrics.gameTypeCounts = gameTypeCounts;
        metrics.datasetTypeCounts = datasetTypeCounts;
        
        emit CategoryMetricsUpdated(block.timestamp, bestResourceType, bestGameType);
    }
    
    // Get category performance metrics
    function getCategoryMetrics(uint256 timestamp) 
        external 
        view 
        returns (CategoryPerformanceMetrics memory) 
    {
        return categoryMetrics[timestamp];
    }
    
    // Structure for community growth statistics
    struct CommunityGrowthStats {
        uint256 timestamp;
        uint256 totalUsers;
        uint256 newUsersDaily;
        uint256 newUsersWeekly;
        uint256 newUsersMonthly;
        uint256 userRetentionRate;
        uint256 averageTimeOnPlatform;
        int256 netGrowthRate;
        uint256[8] usersByRegion; // Count of users by region (simplified)
        uint256[5] usersByActivityLevel; // Count of users by activity level
    }
    
    // Mapping for community growth statistics
    mapping(uint256 => CommunityGrowthStats) public communityStats;
    
    // Event for community growth statistics
    event CommunityStatsUpdated(uint256 timestamp, uint256 totalUsers, int256 netGrowthRate);
    
    // Generate community growth statistics
    function generateCommunityStats() 
        external 
        whenNotPaused 
        onlyOwner 
    {
        // These calculations would typically involve analyzing real user data
        // For this contract, we'll use simplified estimates
        
        uint256 totalUsers = getTotalUsersCount();
        
        // Sample user registrations to estimate growth
        uint256 newUsersDaily = 0;
        uint256 newUsersWeekly = 0;
        uint256 newUsersMonthly = 0;
        
        // Sample 1000 addresses to estimate user growth
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (isRegistered[user]) {
                if (block.timestamp - userProfiles[user].registrationTime <= 1 days) {
                    newUsersDaily++;
                }
                
                if (block.timestamp - userProfiles[user].registrationTime <= 7 days) {
                    newUsersWeekly++;
                }
                
                if (block.timestamp - userProfiles[user].registrationTime <= 30 days) {
                    newUsersMonthly++;
                }
            }
        }
        
        // Scale estimates based on sample size
        if (totalUsers > 1000) {
            uint256 scaleFactor = totalUsers / 1000;
            newUsersDaily *= scaleFactor;
            newUsersWeekly *= scaleFactor;
            newUsersMonthly *= scaleFactor;
        }
        
        // Get active users count for retention calculation
        uint256 activeUsersLast30d = 0;
        for (uint256 i = 0; i < 1000; i++) {
            address user = address(uint160(i + 1));
            
            if (isRegistered[user]) {
                if (block.timestamp - userProfiles[user].lastActivityTime <= 30 days) {
                    activeUsersLast30d++;
                }
            }
        }
        
        // Scale active users estimate
        if (totalUsers > 1000) {
            activeUsersLast30d = activeUsersLast30d * totalUsers / 1000;
        }
        
        // Calculate retention rate
        uint256 retentionRate = totalUsers > 0 ? activeUsersLast30d * 100 / totalUsers : 0;
        
        // Calculate net growth rate
        int256 netGrowthRate = 0;
        if (communityStats[block.timestamp - 30 days].totalUsers > 0) {
            netGrowthRate = (int256(totalUsers) - int256(communityStats[block.timestamp - 30 days].totalUsers)) * 10000 / 
                           int256(communityStats[block.timestamp - 30 days].totalUsers);
        }
        
        // Create region distribution (simplified)
        uint256[8] memory usersByRegion;
        usersByRegion[0] = totalUsers * 25 / 100; // Region 1 - 25%
        usersByRegion[1] = totalUsers * 20 / 100; // Region 2
        usersByRegion[2] = totalUsers * 15 / 100; // Region 3 - 15%
        usersByRegion[3] = totalUsers * 12 / 100; // Region 4 - 12%
        usersByRegion[4] = totalUsers * 10 / 100; // Region 5 - 10%
        usersByRegion[5] = totalUsers * 8 / 100;  // Region 6 - 8%
        usersByRegion[6] = totalUsers * 6 / 100;  // Region 7 - 6%
        usersByRegion[7] = totalUsers * 4 / 100;  // Region 8 - 4%
        
        // Create activity level distribution
        uint256[5] memory usersByActivityLevel;
        usersByActivityLevel[0] = totalUsers * 10 / 100; // Very Low - 10%
        usersByActivityLevel[1] = totalUsers * 20 / 100; // Low - 20%
        usersByActivityLevel[2] = totalUsers * 40 / 100; // Medium - 40%
        usersByActivityLevel[3] = totalUsers * 20 / 100; // High - 20%
        usersByActivityLevel[4] = totalUsers * 10 / 100; // Very High - 10%
        
        // Create new stats
        CommunityGrowthStats storage stats = communityStats[block.timestamp];
        stats.timestamp = block.timestamp;
        stats.totalUsers = totalUsers;
        stats.newUsersDaily = newUsersDaily;
        stats.newUsersWeekly = newUsersWeekly;
        stats.newUsersMonthly = newUsersMonthly;
        stats.userRetentionRate = retentionRate;
        stats.averageTimeOnPlatform = 120 minutes; // Placeholder value
        stats.netGrowthRate = netGrowthRate;
        stats.usersByRegion = usersByRegion;
        stats.usersByActivityLevel = usersByActivityLevel;
        
        emit CommunityStatsUpdated(block.timestamp, totalUsers, netGrowthRate);
    }
    
    // Get community growth statistics
    function getCommunityStats(uint256 timestamp) 
        external 
        view 
        returns (CommunityGrowthStats memory) 
    {
        return communityStats[timestamp];
    }
    
    // ==================== AI & MACHINE LEARNING INTEGRATION FUNCTIONS ====================
    
    // Structure for prediction model
    struct PredictionModel {
        uint256 id;
        string name;
        string description;
        PredictionModelType modelType;
        uint256 creationTime;
        uint256 lastUpdateTime;
        uint256 accuracy;
        uint256 confidenceLevel;
        uint256 dataPointsCount;
        bool isActive;
    }
    
    // Enum for prediction model type
    enum PredictionModelType { PRICE, DEMAND, USAGE, GROWTH, RISK, CUSTOM }
    
    // Structure for prediction result
    struct PredictionResult {
        uint256 modelId;
        uint256 timestamp;
        bytes32 predictionId;
        bytes32 targetId;
        uint256 predictedValue;
        uint256 actualValue;
        uint256 confidence;
        bool isVerified;
    }
    
    // Mapping for prediction models and results
    mapping(uint256 => PredictionModel) public predictionModels;
    mapping(bytes32 => PredictionResult) public predictionResults;
    mapping(uint256 => bytes32[]) public modelPredictions;
    
    // Counter for prediction models
    Counters.Counter private _modelIdCounter;
    
    // Events for prediction models and results
    event PredictionModelCreated(uint256 indexed modelId, string name, PredictionModelType modelType);
    event PredictionResultAdded(bytes32 indexed predictionId, uint256 indexed modelId, uint256 predictedValue);
    event PredictionResultVerified(bytes32 indexed predictionId, uint256 actualValue, uint256 accuracy);
    
    // Register prediction model
    function registerPredictionModel(
        string memory name,
        string memory description,
        PredictionModelType modelType
    ) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        
        // Increment model ID counter
        _modelIdCounter.increment();
        uint256 newModelId = _modelIdCounter.current();
        
        // Create new prediction model
        PredictionModel storage newModel = predictionModels[newModelId];
        newModel.id = newModelId;
        newModel.name = name;
        newModel.description = description;
        newModel.modelType = modelType;
        newModel.creationTime = block.timestamp;
        newModel.lastUpdateTime = block.timestamp;
        newModel.accuracy = 0;
        newModel.confidenceLevel = 50; // 50% default confidence
        newModel.dataPointsCount = 0;
        newModel.isActive = true;
        
        emit PredictionModelCreated(newModelId, name, modelType);
    }
    
    // Add prediction result
    function addPredictionResult(
        uint256 modelId,
        bytes32 targetId,
        uint256 predictedValue,
        uint256 confidence
    ) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(modelId > 0 && modelId <= _modelIdCounter.current(), "Invalid model ID");
        require(predictionModels[modelId].isActive, "Model not active");
        
        // Generate prediction ID
        bytes32 predictionId = keccak256(
            abi.encodePacked(
                modelId,
                targetId,
                predictedValue,
                block.timestamp
            )
        );
        
        // Create new prediction result
        PredictionResult storage newResult = predictionResults[predictionId];
        newResult.modelId = modelId;
        newResult.timestamp = block.timestamp;
        newResult.predictionId = predictionId;
        newResult.targetId = targetId;
        newResult.predictedValue = predictedValue;
        newResult.confidence = confidence;
        newResult.isVerified = false;
        
        // Add to model predictions
        modelPredictions[modelId].push(predictionId);
        
        // Update model
        PredictionModel storage model = predictionModels[modelId];
        model.lastUpdateTime = block.timestamp;
        model.dataPointsCount++;
        
        emit PredictionResultAdded(predictionId, modelId, predictedValue);
    }
    
    // Verify prediction result
    function verifyPredictionResult(
        bytes32 predictionId,
        uint256 actualValue
    ) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(predictionResults[predictionId].timestamp > 0, "Prediction not found");
        require(!predictionResults[predictionId].isVerified, "Prediction already verified");
        
        PredictionResult storage result = predictionResults[predictionId];
        result.actualValue = actualValue;
        result.isVerified = true;
        
        // Calculate accuracy (as percentage)
        uint256 accuracy;
        if (actualValue >= result.predictedValue) {
            accuracy = actualValue > 0 ? 
                (result.predictedValue * 100) / actualValue : 
                0;
        } else {
            accuracy = result.predictedValue > 0 ? 
                (actualValue * 100) / result.predictedValue : 
                0;
        }
        
        // Constrain accuracy to maximum 100%
        if (accuracy > 100) {
            accuracy = 200 - accuracy; // Invert scale for values over 100%
        }
        
        // Update model accuracy
        PredictionModel storage model = predictionModels[result.modelId];
        if (model.dataPointsCount > 1) {
            // Weighted average: (previous_acc * (n-1) + new_acc) / n
            model.accuracy = (model.accuracy * (model.dataPointsCount - 1) + accuracy) / model.dataPointsCount;
        } else {
            model.accuracy = accuracy;
        }
        
        model.lastUpdateTime = block.timestamp;
        
        emit PredictionResultVerified(predictionId, actualValue, accuracy);
    }
    
    // Get prediction model details
    function getPredictionModelDetails(uint256 modelId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            PredictionModelType modelType,
            uint256 accuracy,
            uint256 confidenceLevel,
            uint256 dataPointsCount,
            bool isActive
        ) 
    {
        require(modelId > 0 && modelId <= _modelIdCounter.current(), "Invalid model ID");
        
        PredictionModel storage model = predictionModels[modelId];
        
        return (
            model.name,
            model.description,
            model.modelType,
            model.accuracy,
            model.confidenceLevel,
            model.dataPointsCount,
            model.isActive
        );
    }
    
    // Get prediction result details
    function getPredictionResultDetails(bytes32 predictionId) 
        external 
        view 
        returns (
            uint256 modelId,
            uint256 timestamp,
            bytes32 targetId,
            uint256 predictedValue,
            uint256 actualValue,
            uint256 confidence,
            bool isVerified
        ) 
    {
        PredictionResult storage result = predictionResults[predictionId];
        
        return (
            result.modelId,
            result.timestamp,
            result.targetId,
            result.predictedValue,
            result.actualValue,
            result.confidence,
            result.isVerified
        );
    }
    
    // Get model predictions
    function getModelPredictions(uint256 modelId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        require(modelId > 0 && modelId <= _modelIdCounter.current(), "Invalid model ID");
        
        return modelPredictions[modelId];
    }
    
    // Structure for anomaly detection
    struct AnomalyDetection {
        bytes32 id;
        uint256 timestamp;
        AnomalyType anomalyType;
        uint256 severity;
        bytes32 targetId;
        address reporter;
        string description;
        bool isResolved;
        uint256 resolutionTime;
    }
    
    // Enum for anomaly type
    enum AnomalyType { TRANSACTION, PRICING, USAGE, SECURITY, BEHAVIOR, OTHER }
    
    // Mapping for anomaly detections
    mapping(bytes32 => AnomalyDetection) public anomalyDetections;
    mapping(AnomalyType => bytes32[]) public anomaliesByType;
    mapping(address => bytes32[]) public anomaliesByReporter;
    
    // Event for anomaly detection
    event AnomalyDetected(bytes32 indexed anomalyId, AnomalyType anomalyType, uint256 severity);
    event AnomalyResolved(bytes32 indexed anomalyId, uint256 resolutionTime);
    
    // Report anomaly
    function reportAnomaly(
        AnomalyType anomalyType,
        uint256 severity,
        bytes32 targetId,
        string memory description
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (bytes32)
    {
        require(severity > 0 && severity <= 10, "Severity must be between 1 and 10");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        // Generate anomaly ID
        bytes32 anomalyId = keccak256(
            abi.encodePacked(
                anomalyType,
                targetId,
                msg.sender,
                block.timestamp
            )
        );
        
        // Create new anomaly detection
        AnomalyDetection storage newAnomaly = anomalyDetections[anomalyId];
        newAnomaly.id = anomalyId;
        newAnomaly.timestamp = block.timestamp;
        newAnomaly.anomalyType = anomalyType;
        newAnomaly.severity = severity;
        newAnomaly.targetId = targetId;
        newAnomaly.reporter = msg.sender;
        newAnomaly.description = description;
        newAnomaly.isResolved = false;
        
        // Add to mappings
        anomaliesByType[anomalyType].push(anomalyId);
        anomaliesByReporter[msg.sender].push(anomalyId);
        
        // Reward reporter for reporting anomaly
        userReputation[msg.sender] = userReputation[msg.sender].add(5 * severity);
        
        emit AnomalyDetected(anomalyId, anomalyType, severity);
        
        return anomalyId;
    }
    
    // Resolve anomaly
    function resolveAnomaly(bytes32 anomalyId) 
        external 
        whenNotPaused 
        onlyOwner 
    {
        require(anomalyDetections[anomalyId].timestamp > 0, "Anomaly not found");
        require(!anomalyDetections[anomalyId].isResolved, "Anomaly already resolved");
        
        AnomalyDetection storage anomaly = anomalyDetections[anomalyId];
        anomaly.isResolved = true;
        anomaly.resolutionTime = block.timestamp;
        
        emit AnomalyResolved(anomalyId, block.timestamp);
    }
    
    // Get anomaly details
    function getAnomalyDetails(bytes32 anomalyId) 
        external 
        view 
        returns (
            uint256 timestamp,
            AnomalyType anomalyType,
            uint256 severity,
            bytes32 targetId,
            address reporter,
            string memory description,
            bool isResolved,
            uint256 resolutionTime
        ) 
    {
        AnomalyDetection storage anomaly = anomalyDetections[anomalyId];
        
        return (
            anomaly.timestamp,
            anomaly.anomalyType,
            anomaly.severity,
            anomaly.targetId,
            anomaly.reporter,
            anomaly.description,
            anomaly.isResolved,
            anomaly.resolutionTime
        );
    }
    
    // Get anomalies by type
    function getAnomaliesByType(AnomalyType anomalyType) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return anomaliesByType[anomalyType];
    }
    
    // Get anomalies by reporter
    function getAnomaliesByReporter(address reporter) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return anomaliesByReporter[reporter];
    }
    
    // Calculate risk score for an entity
    function calculateRiskScore(bytes32 entityId, address entityOwner) 
        external 
        view 
        returns (uint256) 
    {
        // Base risk score
        uint256 riskScore = 50; // Start at medium risk
        
        // Adjust based on owner reputation
        if (userReputation[entityOwner] > 500) {
            riskScore = riskScore.sub(10); // Lower risk for high reputation users
        } else if (userReputation[entityOwner] < 100) {
            riskScore = riskScore.add(10); // Higher risk for low reputation users
        }
        
        // Adjust based on anomalies
        uint256 anomalyCount = 0;
        uint256 totalSeverity = 0;
        
        // Simplified check for related anomalies (in real implementation, would scan all anomalies)
        for (uint256 i = 0; i < anomaliesByReporter[entityOwner].length && i < 10; i++) {
            bytes32 anomalyId = anomaliesByReporter[entityOwner][i];
            AnomalyDetection storage anomaly = anomalyDetections[anomalyId];
            
            if (anomaly.targetId == entityId) {
                anomalyCount++;
                totalSeverity = totalSeverity.add(anomaly.severity);
            }
        }
        
        if (anomalyCount > 0) {
            uint256 avgSeverity = totalSeverity.div(anomalyCount);
            riskScore = riskScore.add(avgSeverity * 2);
        }
        
        // Adjust based on longevity
        uint256 entityAge = 0;
        
        // Check if entity is a resource
        for (uint256 i = 1; i <= _resourceIdCounter.current(); i++) {
            if (keccak256(abi.encodePacked(i)) == entityId) {
                entityAge = block.timestamp - resources[i].creationTime;
                break;
            }
        }
        
        // If entity age was found and is significant, reduce risk
        if (entityAge > 30 days) {
            riskScore = riskScore.sub(5);
        }
        if (entityAge > 90 days) {
            riskScore = riskScore.sub(5);
        }
        
        // Constrain to 0-100 range
        if (riskScore > 100) {
            riskScore = 100;
        }
        
        return riskScore;
    }
    
// END OF PART 8/12 - CONTINUE TO PART 9/12
// SPDX-License-Identifier: MIT
// PART 9/12 - MonadEcosystemHubV1
// Extension Systems & Advanced User Management
// Continues from PART 8/12

// CONTINUED FROM PART 8/12

    // ==================== EXTENSION SYSTEMS ====================
    
    // Structure for extension module
    struct ExtensionModule {
        uint256 id;
        string name;
        string description;
        address moduleAddress;
        bytes4 interfaceId;
        bool isActive;
        uint256 creationTime;
        uint256 lastUpdateTime;
        address developer;
        bool isOfficial;
        string documentationURI;
        ExtensionModuleType moduleType;
    }
    
    // Enum for extension module type
    enum ExtensionModuleType { UTILITY, INTEGRATION, SECURITY, ANALYTICS, GOVERNANCE, CUSTOM }
    
    // Structure for extension call data
    struct ExtensionCallData {
        uint256 id;
        uint256 moduleId;
        address caller;
        bytes4 functionSelector;
        bytes parameters;
        uint256 timestamp;
        bool success;
        bytes resultData;
    }
    
    // Mapping for extension modules
    mapping(uint256 => ExtensionModule) public extensionModules;
    mapping(address => bool) public approvedExtensionDevelopers;
    mapping(uint256 => mapping(bytes4 => bool)) public allowedFunctions;
    mapping(address => uint256[]) public userInstalledModules;
    
    // Mapping for extension call data
    mapping(uint256 => ExtensionCallData) public extensionCalls;
    
    // Counter for extension modules and calls
    Counters.Counter private _extensionModuleIdCounter;
    Counters.Counter private _extensionCallIdCounter;
    
    // Events for extension module
    event ExtensionModuleRegistered(uint256 indexed moduleId, string name, address moduleAddress);
    event ExtensionModuleUpdated(uint256 indexed moduleId, bool isActive);
    event ExtensionFunctionCalled(uint256 indexed callId, uint256 indexed moduleId, bytes4 functionSelector);
    event ExtensionModuleInstalled(uint256 indexed moduleId, address indexed user);
    event ExtensionModuleUninstalled(uint256 indexed moduleId, address indexed user);
    
    // Register extension module
    function registerExtensionModule(
        string memory name,
        string memory description,
        address moduleAddress,
        bytes4 interfaceId,
        bytes4[] calldata allowedSelectors,
        string memory documentationURI,
        ExtensionModuleType moduleType
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(moduleAddress != address(0), "Invalid module address");
require(AddressUtils.isContract(moduleAddress), "Address must be a contract"); // <-- ใช้ชื่อ Library ใหม่        require(bytes(documentationURI).length > 0, "Documentation URI cannot be empty");
        
        // Check if caller is approved developer or owner
        bool isOfficial = false;
        if (msg.sender == owner()) {
            isOfficial = true;
        } else {
            require(approvedExtensionDevelopers[msg.sender], "Not an approved developer");
        }
        
        // Increment module ID counter
        _extensionModuleIdCounter.increment();
        uint256 newModuleId = _extensionModuleIdCounter.current();
        
        // Create new extension module
        ExtensionModule storage newModule = extensionModules[newModuleId];
        newModule.id = newModuleId;
        newModule.name = name;
        newModule.description = description;
        newModule.moduleAddress = moduleAddress;
        newModule.interfaceId = interfaceId;
        newModule.isActive = true;
        newModule.creationTime = block.timestamp;
        newModule.lastUpdateTime = block.timestamp;
        newModule.developer = msg.sender;
        newModule.isOfficial = isOfficial;
        newModule.documentationURI = documentationURI;
        newModule.moduleType = moduleType;
        
        // Register allowed function selectors
        for (uint256 i = 0; i < allowedSelectors.length; i++) {
            allowedFunctions[newModuleId][allowedSelectors[i]] = true;
        }
        
        // Pay registration fee if not official
        if (!isOfficial) {
            uint256 registrationFee = 0.05 ether;
            require(userBalances[msg.sender] >= registrationFee, "Insufficient balance for registration fee");
            
            userBalances[msg.sender] = userBalances[msg.sender].sub(registrationFee);
            userBalances[feeCollector] = userBalances[feeCollector].add(registrationFee);
            
            emit FeePaid(msg.sender, registrationFee, "Extension Module Registration");
        }
        
        emit ExtensionModuleRegistered(newModuleId, name, moduleAddress);
    }
    
    // Update extension module
    function updateExtensionModule(
        uint256 moduleId,
        string memory description,
        bool isActive,
        string memory documentationURI
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        
        ExtensionModule storage module = extensionModules[moduleId];
        
        // Check if caller is module developer or owner
        require(
            module.developer == msg.sender || owner() == msg.sender, 
            "Not the module developer or owner"
        );
        
        // Update module
        module.description = description;
        module.isActive = isActive;
        module.documentationURI = documentationURI;
        module.lastUpdateTime = block.timestamp;
        
        emit ExtensionModuleUpdated(moduleId, isActive);
    }
    
    // Approve extension developer
    function approveExtensionDeveloper(address developer) 
        external 
        onlyOwner 
    {
        require(developer != address(0), "Invalid developer address");
        approvedExtensionDevelopers[developer] = true;
    }
    
    // Revoke extension developer approval
    function revokeExtensionDeveloper(address developer) 
        external 
        onlyOwner 
    {
        approvedExtensionDevelopers[developer] = false;
    }
    
    // Install extension module for user
    function installExtensionModule(uint256 moduleId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        require(extensionModules[moduleId].isActive, "Module not active");
        
        // Check if user already installed this module
        bool alreadyInstalled = false;
        for (uint256 i = 0; i < userInstalledModules[msg.sender].length; i++) {
            if (userInstalledModules[msg.sender][i] == moduleId) {
                alreadyInstalled = true;
                break;
            }
        }
        
        require(!alreadyInstalled, "Module already installed");
        
        // Pay installation fee if module is not official
        if (!extensionModules[moduleId].isOfficial) {
            uint256 installationFee = 0.01 ether;
            require(userBalances[msg.sender] >= installationFee, "Insufficient balance for installation fee");
            
            userBalances[msg.sender] = userBalances[msg.sender].sub(installationFee);
            
            // Split fee between developer and platform
            uint256 developerShare = installationFee.mul(70).div(100); // 70% to developer
            uint256 platformShare = installationFee.sub(developerShare); // 30% to platform
            
            userBalances[extensionModules[moduleId].developer] = userBalances[extensionModules[moduleId].developer].add(developerShare);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformShare);
            
            emit FeePaid(msg.sender, installationFee, "Extension Module Installation");
        }
        
        // Add to user's installed modules
        userInstalledModules[msg.sender].push(moduleId);
        
        emit ExtensionModuleInstalled(moduleId, msg.sender);
    }
    
    // Uninstall extension module for user
    function uninstallExtensionModule(uint256 moduleId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        
        // Find and remove module from user's installed modules
        bool found = false;
        for (uint256 i = 0; i < userInstalledModules[msg.sender].length; i++) {
            if (userInstalledModules[msg.sender][i] == moduleId) {
                // Replace with the last element and pop
                userInstalledModules[msg.sender][i] = userInstalledModules[msg.sender][userInstalledModules[msg.sender].length - 1];
                userInstalledModules[msg.sender].pop();
                found = true;
                break;
            }
        }
        
        require(found, "Module not installed");
        
        emit ExtensionModuleUninstalled(moduleId, msg.sender);
    }
    
    // Call extension module function
    function callExtensionFunction(
        uint256 moduleId,
        bytes4 functionSelector,
        bytes memory parameters
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        returns (bytes memory)
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        require(extensionModules[moduleId].isActive, "Module not active");
        require(allowedFunctions[moduleId][functionSelector], "Function selector not allowed");
        
        // Check if user has installed this module
        bool isInstalled = false;
        for (uint256 i = 0; i < userInstalledModules[msg.sender].length; i++) {
            if (userInstalledModules[msg.sender][i] == moduleId) {
                isInstalled = true;
                break;
            }
        }
        
        require(isInstalled, "Module not installed");
        
        // Construct function call data
        bytes memory data = abi.encodePacked(functionSelector, parameters);
        
        // Get module address
        address moduleAddress = extensionModules[moduleId].moduleAddress;
        
        // Call module function
        (bool success, bytes memory result) = moduleAddress.call{value: msg.value}(data);
        
        // Increment call ID counter
        _extensionCallIdCounter.increment();
        uint256 newCallId = _extensionCallIdCounter.current();
        
        // Store call data
        ExtensionCallData storage newCall = extensionCalls[newCallId];
        newCall.id = newCallId;
        newCall.moduleId = moduleId;
        newCall.caller = msg.sender;
        newCall.functionSelector = functionSelector;
        newCall.parameters = parameters;
        newCall.timestamp = block.timestamp;
        newCall.success = success;
        if (success) {
            newCall.resultData = result;
        }
        
        // Update module last update time
        extensionModules[moduleId].lastUpdateTime = block.timestamp;
        
        emit ExtensionFunctionCalled(newCallId, moduleId, functionSelector);
        
        require(success, "Extension function call failed");
        
        return result;
    }
    
    // Get extension module details
    function getExtensionModuleDetails(uint256 moduleId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address moduleAddress,
            bytes4 interfaceId,
            bool isActive,
            uint256 creationTime,
            address developer,
            bool isOfficial,
            string memory documentationURI,
            ExtensionModuleType moduleType
        ) 
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        
        ExtensionModule storage module = extensionModules[moduleId];
        
        return (
            module.name,
            module.description,
            module.moduleAddress,
            module.interfaceId,
            module.isActive,
            module.creationTime,
            module.developer,
            module.isOfficial,
            module.documentationURI,
            module.moduleType
        );
    }
    
    // Get user installed modules
    function getUserInstalledModules(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userInstalledModules[user];
    }
    
    // Get extension call details
    function getExtensionCallDetails(uint256 callId) 
        external 
        view 
        returns (
            uint256 moduleId,
            address caller,
            bytes4 functionSelector,
            uint256 timestamp,
            bool success
        ) 
    {
        require(callId > 0 && callId <= _extensionCallIdCounter.current(), "Invalid call ID");
        
        ExtensionCallData storage call = extensionCalls[callId];
        
        return (
            call.moduleId,
            call.caller,
            call.functionSelector,
            call.timestamp,
            call.success
        );
    }
    
    // Get extension call result data
    function getExtensionCallResultData(uint256 callId) 
        external 
        view 
        returns (bytes memory) 
    {
        require(callId > 0 && callId <= _extensionCallIdCounter.current(), "Invalid call ID");
        require(extensionCalls[callId].success, "Call did not succeed");
        
        return extensionCalls[callId].resultData;
    }
    
    // Check if function selector is allowed for module
    function isFunctionAllowed(uint256 moduleId, bytes4 functionSelector) 
        external 
        view 
        returns (bool) 
    {
        require(moduleId > 0 && moduleId <= _extensionModuleIdCounter.current(), "Invalid module ID");
        
        return allowedFunctions[moduleId][functionSelector];
    }
    
    // ==================== PLUGIN SYSTEM ====================
    
    // Structure for plugin
    struct Plugin {
        uint256 id;
        string name;
        string description;
        address pluginAddress;
        PluginCategory category;
        uint256 version;
        address developer;
        bool isActive;
        uint256 installationCount;
        uint256 creationTime;
        uint256 lastUpdateTime;
        uint256 fee;
        string documentationURI;
    }
    
    // Enum for plugin category
    enum PluginCategory { UTILITY, INTEGRATION, UI, ANALYTICS, SECURITY, CUSTOM }
    
    // Struct for plugin version
    struct PluginVersion {
        uint256 pluginId;
        uint256 version;
        string changeLog;
        uint256 releaseTime;
        address releaser;
        bool isDeprecated;
    }
    
    // Mapping for plugins
    mapping(uint256 => Plugin) public plugins;
    mapping(address => uint256[]) public developerPlugins;
    mapping(address => uint256[]) public userPlugins;
    mapping(uint256 => mapping(uint256 => PluginVersion)) public pluginVersions;
    mapping(uint256 => uint256) public latestPluginVersion;
    
    // Counter for plugins
    Counters.Counter private _pluginIdCounter;
    
    // Events for plugin
    event PluginRegistered(uint256 indexed pluginId, string name, address developer);
    event PluginUpdated(uint256 indexed pluginId, uint256 version);
    event PluginInstalled(uint256 indexed pluginId, address indexed user);
    event PluginUninstalled(uint256 indexed pluginId, address indexed user);
    
    // Register plugin
    function registerPlugin(
        string memory name,
        string memory description,
        address pluginAddress,
        PluginCategory category,
        uint256 fee,
        string memory documentationURI,
        string memory initialChangeLog
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(pluginAddress != address(0), "Invalid plugin address");
require(AddressUtils.isContract(pluginAddress), "Address must be a contract"); // <--- แก้ไขให้เรียกผ่าน AddressUtils        require(bytes(documentationURI).length > 0, "Documentation URI cannot be empty");
        require(fee <= 0.1 ether, "Fee too high");
        
        // Increment plugin ID counter
        _pluginIdCounter.increment();
        uint256 newPluginId = _pluginIdCounter.current();
        
        // Create new plugin
        Plugin storage newPlugin = plugins[newPluginId];
        newPlugin.id = newPluginId;
        newPlugin.name = name;
        newPlugin.description = description;
        newPlugin.pluginAddress = pluginAddress;
        newPlugin.category = category;
        newPlugin.version = 1;
        newPlugin.developer = msg.sender;
        newPlugin.isActive = true;
        newPlugin.installationCount = 0;
        newPlugin.creationTime = block.timestamp;
        newPlugin.lastUpdateTime = block.timestamp;
        newPlugin.fee = fee;
        newPlugin.documentationURI = documentationURI;
        
        // Add to developer's plugins
        developerPlugins[msg.sender].push(newPluginId);
        
        // Create initial version
        PluginVersion storage initialVersion = pluginVersions[newPluginId][1];
        initialVersion.pluginId = newPluginId;
        initialVersion.version = 1;
        initialVersion.changeLog = initialChangeLog;
        initialVersion.releaseTime = block.timestamp;
        initialVersion.releaser = msg.sender;
        initialVersion.isDeprecated = false;
        
        // Set latest version
        latestPluginVersion[newPluginId] = 1;
        
        // Pay registration fee
        uint256 registrationFee = 0.05 ether;
        require(userBalances[msg.sender] >= registrationFee, "Insufficient balance for registration fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(registrationFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(registrationFee);
        
        emit FeePaid(msg.sender, registrationFee, "Plugin Registration");
        emit PluginRegistered(newPluginId, name, msg.sender);
    }
    
    // Update plugin
    function updatePlugin(
        uint256 pluginId,
        string memory description,
        uint256 fee,
        bool isActive,
        string memory documentationURI
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        require(fee <= 0.1 ether, "Fee too high");
        
        Plugin storage plugin = plugins[pluginId];
        
        // Check if caller is plugin developer
        require(plugin.developer == msg.sender, "Not the plugin developer");
        
        // Update plugin
        plugin.description = description;
        plugin.fee = fee;
        plugin.isActive = isActive;
        plugin.documentationURI = documentationURI;
        plugin.lastUpdateTime = block.timestamp;
        
        emit PluginUpdated(pluginId, plugin.version);
    }
    
    // Release new plugin version
    function releasePluginVersion(
        uint256 pluginId,
        address newPluginAddress,
        string memory changeLog
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        require(newPluginAddress != address(0), "Invalid plugin address");
        require(AddressUtils.isContract(newPluginAddress), "Address must be a contract"); // <-- แก้ไขให้เรียกผ่าน AddressUtils
        require(bytes(changeLog).length > 0, "Change log cannot be empty");
        
        Plugin storage plugin = plugins[pluginId];
        
        // Check if caller is plugin developer
        require(plugin.developer == msg.sender, "Not the plugin developer");
        
        // Increment version
        uint256 newVersion = plugin.version + 1;
        plugin.version = newVersion;
        plugin.pluginAddress = newPluginAddress;
        plugin.lastUpdateTime = block.timestamp;
        
        // Create new version
        PluginVersion storage newVersionData = pluginVersions[pluginId][newVersion];
        newVersionData.pluginId = pluginId;
        newVersionData.version = newVersion;
        newVersionData.changeLog = changeLog;
        newVersionData.releaseTime = block.timestamp;
        newVersionData.releaser = msg.sender;
        newVersionData.isDeprecated = false;
        
        // Set latest version
        latestPluginVersion[pluginId] = newVersion;
        
        // Mark previous version as deprecated
        pluginVersions[pluginId][newVersion - 1].isDeprecated = true;
        
        // Pay release fee
        uint256 releaseFee = 0.02 ether;
        require(userBalances[msg.sender] >= releaseFee, "Insufficient balance for release fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(releaseFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(releaseFee);
        
        emit FeePaid(msg.sender, releaseFee, "Plugin Version Release");
        emit PluginUpdated(pluginId, newVersion);
    }
    
    // Install plugin
    function installPlugin(uint256 pluginId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        
        Plugin storage plugin = plugins[pluginId];
        require(plugin.isActive, "Plugin not active");
        
        // Check if user already installed this plugin
        for (uint256 i = 0; i < userPlugins[msg.sender].length; i++) {
            require(userPlugins[msg.sender][i] != pluginId, "Plugin already installed");
        }
        
        // Pay installation fee
        if (plugin.fee > 0) {
            require(userBalances[msg.sender] >= plugin.fee, "Insufficient balance for plugin fee");
            
            userBalances[msg.sender] = userBalances[msg.sender].sub(plugin.fee);
            
            // Split fee between developer and platform
            uint256 developerShare = plugin.fee.mul(80).div(100); // 80% to developer
            uint256 platformShare = plugin.fee.sub(developerShare); // 20% to platform
            
            userBalances[plugin.developer] = userBalances[plugin.developer].add(developerShare);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformShare);
            
            emit FeePaid(msg.sender, plugin.fee, "Plugin Installation");
        }
        
        // Add to user's plugins
        userPlugins[msg.sender].push(pluginId);
        
        // Increment installation count
        plugin.installationCount++;
        
        emit PluginInstalled(pluginId, msg.sender);
    }
    
    // Uninstall plugin
    function uninstallPlugin(uint256 pluginId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        
        // Find and remove plugin from user's plugins
        bool found = false;
        for (uint256 i = 0; i < userPlugins[msg.sender].length; i++) {
            if (userPlugins[msg.sender][i] == pluginId) {
                // Replace with the last element and pop
                userPlugins[msg.sender][i] = userPlugins[msg.sender][userPlugins[msg.sender].length - 1];
                userPlugins[msg.sender].pop();
                found = true;
                break;
            }
        }
        
        require(found, "Plugin not installed");
        
        // Decrement installation count
        plugins[pluginId].installationCount--;
        
        emit PluginUninstalled(pluginId, msg.sender);
    }
    
    // Get plugin details
    function getPluginDetails(uint256 pluginId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address pluginAddress,
            PluginCategory category,
            uint256 version,
            address developer,
            bool isActive,
            uint256 installationCount,
            uint256 fee,
            string memory documentationURI
        ) 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        
        Plugin storage plugin = plugins[pluginId];
        
        return (
            plugin.name,
            plugin.description,
            plugin.pluginAddress,
            plugin.category,
            plugin.version,
            plugin.developer,
            plugin.isActive,
            plugin.installationCount,
            plugin.fee,
            plugin.documentationURI
        );
    }
    
    // Get plugin version details
    function getPluginVersionDetails(uint256 pluginId, uint256 version) 
        external 
        view 
        returns (
            string memory changeLog,
            uint256 releaseTime,
            address releaser,
            bool isDeprecated
        ) 
    {
        require(pluginId > 0 && pluginId <= _pluginIdCounter.current(), "Invalid plugin ID");
        require(version > 0 && version <= plugins[pluginId].version, "Invalid version");
        
        PluginVersion storage versionData = pluginVersions[pluginId][version];
        
        return (
            versionData.changeLog,
            versionData.releaseTime,
            versionData.releaser,
            versionData.isDeprecated
        );
    }
    
    // Get developer plugins
    function getDeveloperPlugins(address developer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return developerPlugins[developer];
    }
    
    // Get user plugins
    function getUserPlugins(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userPlugins[user];
    }
    
    // ==================== ADVANCED USER MANAGEMENT ====================
    
    // Structure for user group
    struct UserGroup {
        uint256 id;
        string name;
        string description;
        address creator;
        uint256 creationTime;
        uint256 memberCount;
        bool isPublic;
        bool requiresApproval;
        uint256 minReputationRequired;
        address[] admins;
        UserGroupPermissions permissions;
    }
    
    // Structure for user group permissions
    struct UserGroupPermissions {
        bool canCreateResources;
        bool canCreateExchanges;
        bool canCreateProposals;
        bool canCreateGames;
        bool canCreateDatasets;
        bool canInviteMembers;
        bool canRemoveMembers;
    }
    
    // Struct for group membership
    struct GroupMembership {
        uint256 groupId;
        address member;
        uint256 joinTime;
        MembershipStatus status;
        string role;
    }
    
    // Enum for membership status
    enum MembershipStatus { PENDING, ACTIVE, SUSPENDED, BANNED }
    
    // Mapping for user groups
    mapping(uint256 => UserGroup) public userGroups;
    mapping(uint256 => mapping(address => GroupMembership)) public groupMemberships;
    mapping(address => uint256[]) public userGroupIds;
    
    // Counter for user groups
    Counters.Counter private _userGroupIdCounter;
    
    // Events for user groups
    event UserGroupCreated(uint256 indexed groupId, string name, address creator);
    event UserGroupUpdated(uint256 indexed groupId, string name);
    event UserJoinedGroup(uint256 indexed groupId, address indexed user, MembershipStatus status);
    event UserLeftGroup(uint256 indexed groupId, address indexed user);
    event UserGroupRoleUpdated(uint256 indexed groupId, address indexed user, string role);
    
    // Create user group
    function createUserGroup(
        string memory name,
        string memory description,
        bool isPublic,
        bool requiresApproval,
        uint256 minReputationRequired,
        address[] memory initialAdmins,
        UserGroupPermissions memory permissions
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(initialAdmins.length)
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        
        // Increment group ID counter
        _userGroupIdCounter.increment();
        uint256 newGroupId = _userGroupIdCounter.current();
        
        // Create new user group
        UserGroup storage newGroup = userGroups[newGroupId];
        newGroup.id = newGroupId;
        newGroup.name = name;
        newGroup.description = description;
        newGroup.creator = msg.sender;
        newGroup.creationTime = block.timestamp;
        newGroup.memberCount = 1; // Creator is the first member
        newGroup.isPublic = isPublic;
        newGroup.requiresApproval = requiresApproval;
        newGroup.minReputationRequired = minReputationRequired;
        newGroup.permissions = permissions;
        
        // Add creator as admin
        newGroup.admins.push(msg.sender);
        
        // Add initial admins
        for (uint256 i = 0; i < initialAdmins.length; i++) {
            address admin = initialAdmins[i];
            require(admin != address(0), "Invalid admin address");
            require(admin != msg.sender, "Creator already an admin");
            require(isRegistered[admin], "Admin not registered");
            
            newGroup.admins.push(admin);
        }
        
        // Add creator as member
        GroupMembership storage creatorMembership = groupMemberships[newGroupId][msg.sender];
        creatorMembership.groupId = newGroupId;
        creatorMembership.member = msg.sender;
        creatorMembership.joinTime = block.timestamp;
        creatorMembership.status = MembershipStatus.ACTIVE;
        creatorMembership.role = "Creator";
        
        // Add to creator's groups
        userGroupIds[msg.sender].push(newGroupId);
        
        emit UserGroupCreated(newGroupId, name, msg.sender);
    }
    
    // Update user group
    function updateUserGroup(
        uint256 groupId,
        string memory description,
        bool isPublic,
        bool requiresApproval,
        uint256 minReputationRequired,
        UserGroupPermissions memory permissions
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator or admin
        bool isAdmin = false;
        if (group.creator == msg.sender) {
            isAdmin = true;
        } else {
            for (uint256 i = 0; i < group.admins.length; i++) {
                if (group.admins[i] == msg.sender) {
                    isAdmin = true;
                    break;
                }
            }
        }
        
        require(isAdmin, "Not group creator or admin");
        
        // Update group
        group.description = description;
        group.isPublic = isPublic;
        group.requiresApproval = requiresApproval;
        group.minReputationRequired = minReputationRequired;
        group.permissions = permissions;
        
        emit UserGroupUpdated(groupId, group.name);
    }
    
    // Add admin to group
    function addGroupAdmin(uint256 groupId, address admin) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        require(admin != address(0), "Invalid admin address");
        require(isRegistered[admin], "Admin not registered");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator
        require(group.creator == msg.sender, "Not group creator");
        
        // Check if already an admin
        for (uint256 i = 0; i < group.admins.length; i++) {
            require(group.admins[i] != admin, "Already an admin");
        }
        
        // Add as admin
        group.admins.push(admin);
    }
    
    // Remove admin from group
    function removeGroupAdmin(uint256 groupId, address admin) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator
        require(group.creator == msg.sender, "Not group creator");
        
        // Find and remove admin
        bool found = false;
        for (uint256 i = 0; i < group.admins.length; i++) {
            if (group.admins[i] == admin) {
                // Replace with the last element and pop
                group.admins[i] = group.admins[group.admins.length - 1];
                group.admins.pop();
                found = true;
                break;
            }
        }
        
        require(found, "Not an admin");
    }
    
    // Join user group
    function joinUserGroup(uint256 groupId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        require(group.isPublic, "Group is not public");
        
        // Check reputation requirement
        require(userReputation[msg.sender] >= group.minReputationRequired, "Insufficient reputation");
        
        // Check if already a member
        require(groupMemberships[groupId][msg.sender].joinTime == 0, "Already a member or pending");
        
        // Add as member with appropriate status
        GroupMembership storage membership = groupMemberships[groupId][msg.sender];
        membership.groupId = groupId;
        membership.member = msg.sender;
        membership.joinTime = block.timestamp;
        
        if (group.requiresApproval) {
            membership.status = MembershipStatus.PENDING;
        } else {
            membership.status = MembershipStatus.ACTIVE;
            group.memberCount++;
        }
        
        membership.role = "Member";
        
        // Add to user's groups
        userGroupIds[msg.sender].push(groupId);
        
        emit UserJoinedGroup(groupId, msg.sender, membership.status);
    }
    
    // Approve member join request
    function approveGroupJoinRequest(uint256 groupId, address user) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator or admin
        bool isAdmin = false;
        if (group.creator == msg.sender) {
            isAdmin = true;
        } else {
            for (uint256 i = 0; i < group.admins.length; i++) {
                if (group.admins[i] == msg.sender) {
                    isAdmin = true;
                    break;
                }
            }
        }
        
        require(isAdmin, "Not group creator or admin");
        
        // Check if user has a pending request
        GroupMembership storage membership = groupMemberships[groupId][user];
        require(membership.joinTime > 0, "No join request found");
        require(membership.status == MembershipStatus.PENDING, "Not in pending status");
        
        // Approve request
        membership.status = MembershipStatus.ACTIVE;
        group.memberCount++;
        
        emit UserJoinedGroup(groupId, user, MembershipStatus.ACTIVE);
    }
    
    // Reject member join request
    function rejectGroupJoinRequest(uint256 groupId, address user) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator or admin
        bool isAdmin = false;
        if (group.creator == msg.sender) {
            isAdmin = true;
        } else {
            for (uint256 i = 0; i < group.admins.length; i++) {
                if (group.admins[i] == msg.sender) {
                    isAdmin = true;
                    break;
                }
            }
        }
        
        require(isAdmin, "Not group creator or admin");
        
        // Check if user has a pending request
        GroupMembership storage membership = groupMemberships[groupId][user];
        require(membership.joinTime > 0, "No join request found");
        require(membership.status == MembershipStatus.PENDING, "Not in pending status");
        
        // Remove from user's groups
        for (uint256 i = 0; i < userGroupIds[user].length; i++) {
            if (userGroupIds[user][i] == groupId) {
                userGroupIds[user][i] = userGroupIds[user][userGroupIds[user].length - 1];
                userGroupIds[user].pop();
                break;
            }
        }
        
        // Delete membership
        delete groupMemberships[groupId][user];
    }
    
    // Leave user group
    function leaveUserGroup(uint256 groupId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Cannot leave if you're the creator
        require(group.creator != msg.sender, "Creator cannot leave group");
        
        // Check if a member
        GroupMembership storage membership = groupMemberships[groupId][msg.sender];
        require(membership.joinTime > 0, "Not a member");
        
        // If active member, decrement count
        if (membership.status == MembershipStatus.ACTIVE) {
            group.memberCount--;
        }
        
        // Remove from user's groups
        for (uint256 i = 0; i < userGroupIds[msg.sender].length; i++) {
            if (userGroupIds[msg.sender][i] == groupId) {
                userGroupIds[msg.sender][i] = userGroupIds[msg.sender][userGroupIds[msg.sender].length - 1];
                userGroupIds[msg.sender].pop();
                break;
            }
        }
        
        // Remove from admins if applicable
        for (uint256 i = 0; i < group.admins.length; i++) {
            if (group.admins[i] == msg.sender) {
                group.admins[i] = group.admins[group.admins.length - 1];
                group.admins.pop();
                break;
            }
        }
        
        // Delete membership
        delete groupMemberships[groupId][msg.sender];
        
        emit UserLeftGroup(groupId, msg.sender);
    }
    
    // Update member role
    function updateGroupMemberRole(uint256 groupId, address member, string memory role) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        require(bytes(role).length > 0, "Role cannot be empty");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator or admin
        bool isAdmin = false;
        if (group.creator == msg.sender) {
            isAdmin = true;
        } else {
            for (uint256 i = 0; i < group.admins.length; i++) {
                if (group.admins[i] == msg.sender) {
                    isAdmin = true;
                    break;
                }
            }
        }
        
        require(isAdmin, "Not group creator or admin");
        
        // Check if member
        GroupMembership storage membership = groupMemberships[groupId][member];
        require(membership.joinTime > 0, "Not a member");
        require(membership.status == MembershipStatus.ACTIVE, "Member not active");
        
        // Update role
        membership.role = role;
        
        emit UserGroupRoleUpdated(groupId, member, role);
    }
    
    // Remove member from group
    function removeGroupMember(uint256 groupId, address member) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        // Check if caller is creator or admin
        bool isAdmin = false;
        if (group.creator == msg.sender) {
            isAdmin = true;
        } else {
            for (uint256 i = 0; i < group.admins.length; i++) {
                if (group.admins[i] == msg.sender) {
                    isAdmin = true;
                    break;
                }
            }
        }
        
        require(isAdmin, "Not group creator or admin");
        
        // Cannot remove creator
        require(group.creator != member, "Cannot remove creator");
        
        // Check if member
        GroupMembership storage membership = groupMemberships[groupId][member];
        require(membership.joinTime > 0, "Not a member");
        
        // If active member, decrement count
        if (membership.status == MembershipStatus.ACTIVE) {
            group.memberCount--;
        }
        
        // Remove from user's groups
        for (uint256 i = 0; i < userGroupIds[member].length; i++) {
            if (userGroupIds[member][i] == groupId) {
                userGroupIds[member][i] = userGroupIds[member][userGroupIds[member].length - 1];
                userGroupIds[member].pop();
                break;
            }
        }
        
        // Remove from admins if applicable
        for (uint256 i = 0; i < group.admins.length; i++) {
            if (group.admins[i] == member) {
                group.admins[i] = group.admins[group.admins.length - 1];
                group.admins.pop();
                break;
            }
        }
        
        // Delete membership
        delete groupMemberships[groupId][member];
        
        emit UserLeftGroup(groupId, member);
    }
    
    // Get user group details
    function getUserGroupDetails(uint256 groupId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address creator,
            uint256 creationTime,
            uint256 memberCount,
            bool isPublic,
            bool requiresApproval,
            uint256 minReputationRequired,
            UserGroupPermissions memory permissions
        ) 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        return (
            group.name,
            group.description,
            group.creator,
            group.creationTime,
            group.memberCount,
            group.isPublic,
            group.requiresApproval,
            group.minReputationRequired,
            group.permissions
        );
    }
    
    // Get group admins
    function getGroupAdmins(uint256 groupId) 
        external 
        view 
        returns (address[] memory) 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        return userGroups[groupId].admins;
    }
    
    // Get user membership details
    function getUserMembershipDetails(uint256 groupId, address user) 
        external 
        view 
        returns (
            uint256 joinTime,
            MembershipStatus status,
            string memory role
        ) 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        GroupMembership storage membership = groupMemberships[groupId][user];
        
        return (
            membership.joinTime,
            membership.status,
            membership.role
        );
    }
    
    // Get user's groups
    function getUserGroups(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userGroupIds[user];
    }
    
    // Check if user is group admin
    function isGroupAdmin(uint256 groupId, address user) 
        external 
        view 
        returns (bool) 
    {
        require(groupId > 0 && groupId <= _userGroupIdCounter.current(), "Invalid group ID");
        
        UserGroup storage group = userGroups[groupId];
        
        if (group.creator == user) {
            return true;
        }
        
        for (uint256 i = 0; i < group.admins.length; i++) {
            if (group.admins[i] == user) {
                return true;
            }
        }
        
        return false;
    }
    
    // Structure for user connection
    struct UserConnection {
        address from;
        address to;
        uint256 timestamp;
        ConnectionStatus status;
        string connectionType;
    }
    
    // Enum for connection status
    enum ConnectionStatus { PENDING, ACCEPTED, REJECTED, BLOCKED }
    
    // Mapping for user connections
    mapping(address => mapping(address => UserConnection)) public userConnections;
    mapping(address => address[]) public userConnectedUsers;
    
    // Events for user connections
    event ConnectionRequested(address indexed from, address indexed to, string connectionType);
    event ConnectionStatusChanged(address indexed from, address indexed to, ConnectionStatus status);
    
    // Request connection
    function requestConnection(address to, string memory connectionType) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(to != address(0), "Invalid address");
        require(to != msg.sender, "Cannot connect to self");
        require(isRegistered[to], "User not registered");
        require(bytes(connectionType).length > 0, "Connection type cannot be empty");
        
        // Check if connection already exists
        UserConnection storage existingConnection = userConnections[msg.sender][to];
        require(existingConnection.timestamp == 0, "Connection already exists");
        
        // Check if blocked
        UserConnection storage reverseConnection = userConnections[to][msg.sender];
        require(reverseConnection.status != ConnectionStatus.BLOCKED, "Connection blocked");
        
        // Create connection request
        UserConnection storage newConnection = userConnections[msg.sender][to];
        newConnection.from = msg.sender;
        newConnection.to = to;
        newConnection.timestamp = block.timestamp;
        newConnection.status = ConnectionStatus.PENDING;
        newConnection.connectionType = connectionType;
        
        emit ConnectionRequested(msg.sender, to, connectionType);
    }
    
    // Accept connection
    function acceptConnection(address from) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(from != address(0), "Invalid address");
        
        // Check if connection request exists
        UserConnection storage connection = userConnections[from][msg.sender];
        require(connection.timestamp > 0, "No connection request");
        require(connection.status == ConnectionStatus.PENDING, "Connection not pending");
        
        // Accept connection
        connection.status = ConnectionStatus.ACCEPTED;
        
        // Add bidirectional connection
        UserConnection storage reverseConnection = userConnections[msg.sender][from];
        reverseConnection.from = msg.sender;
        reverseConnection.to = from;
        reverseConnection.timestamp = block.timestamp;
        reverseConnection.status = ConnectionStatus.ACCEPTED;
        reverseConnection.connectionType = connection.connectionType;
        
        // Add to connected users lists
        userConnectedUsers[from].push(msg.sender);
        userConnectedUsers[msg.sender].push(from);
        
        emit ConnectionStatusChanged(from, msg.sender, ConnectionStatus.ACCEPTED);
    }
    
    // Reject connection
   
    
    // Block user
    
    
    // Unblock user
  
    
    // Remove connection
   
    
    // Get connection status
   
    
    // Get connected users
   
    
    // Check if users are connected
    
    
    // Structure for user notification
    struct UserNotification {
        uint256 id;
        address recipient;
        string notificationType;
        bytes32 entityId;
        string content;
        uint256 timestamp;
        bool isRead;
    }
    
    // Mapping for user notifications
    mapping(address => mapping(uint256 => UserNotification)) public userNotifications;
    mapping(address => uint256) public userNotificationCount;
    mapping(address => uint256) public userUnreadNotificationCount;
    
    // Event for user notification
   
    // Create notification
   
    
    // Mark notification as read
  
    
    // Mark all notifications as read
  
    
    // Get notification details
   
    
    // Get user notifications
 
    
    // Get unread notification count
   
    
    // Structure for user achievement
    struct UserAchievement {
        uint256 id;
        string name;
        string description;
        uint256 unlockTimestamp;
        uint256 points;
        string badgeURI;
        AchievementCategory category;
    }
    
    // Enum for achievement category
    enum AchievementCategory { RESOURCE, EXCHANGE, GOVERNANCE, GAME, DATASET, SOCIAL, GENERAL }
    
    // Mapping for user achievements
    mapping(address => mapping(uint256 => UserAchievement)) public userAchievements;
    mapping(address => uint256) public userAchievementCount;
    mapping(address => uint256) public userAchievementPoints;
    
    // Event for user achievement
    
    // Unlock achievement
    
    
    // Get user achievements
  
    
    // Get achievement details
   
    
    // Get user achievement points
    
    
    // Structure for user rating
    
    
    // Enum for rating category    
    // Mapping for user ratings
    mapping(address => mapping(address => UserRating)) public userRatings;
    mapping(address => address[]) public userRaters;
    mapping(address => uint256) public userRatingSum;
    mapping(address => uint256) public userRatingCount;
    
    // Event for user rating
    event UserRated(address indexed rater, address indexed rated, uint8 score);
    
    // Rate user
   
    
    // Address feedback
    
    
    // Get feedback details
   
    
    // Get user feedback IDs
   
    
// END OF PART 9/12 - CONTINUE TO PART 10/12
// SPDX-License-Identifier: MIT
// PART 10/12 - MonadEcosystemHubV1
// Advanced Payments & Financial Functions
// Continues from PART 9/12

// CONTINUED FROM PART 9/12

    // ==================== ADVANCED PAYMENTS & FINANCIAL FUNCTIONS ====================
    
    // Structure for payment
    struct Payment {
        uint256 id;
        address sender;
        address recipient;
        uint256 amount;
        PaymentType paymentType;
        PaymentStatus status;
        uint256 creationTime;
        uint256 completionTime;
        string description;
        bytes32 referenceId;
    }
    
    // Enum for payment type
    enum PaymentType { DIRECT, SCHEDULED, RECURRING, CONDITIONAL, SPLIT, BATCH }
    
    // Enum for payment status
    enum PaymentStatus { PENDING, COMPLETED, CANCELLED, FAILED, REFUNDED }
    
    // Structure for payment condition
    struct PaymentCondition {
        bytes32 conditionId;
        ConditionType conditionType;
        uint256 deadline;
        bool isFulfilled;
        address verifier;
        bytes data;
    }
    
    // Enum for condition type
    enum ConditionType { TIME, ORACLE, MULTI_SIG, EXTERNAL, CUSTOM }
    
    // Mapping for payments
    mapping(uint256 => Payment) public payments;
    mapping(uint256 => PaymentCondition) public paymentConditions;
    mapping(address => uint256[]) public userSentPayments;
    mapping(address => uint256[]) public userReceivedPayments;
    mapping(bytes32 => uint256) public referenceToPaymentId;
    
    // Counter for payments
    Counters.Counter private _paymentIdCounter;
    
    // Events for payments
    event PaymentCreated(uint256 indexed paymentId, address indexed sender, address indexed recipient, uint256 amount);
    event PaymentStatusChanged(uint256 indexed paymentId, PaymentStatus status);
    event PaymentConditionFulfilled(uint256 indexed paymentId, bytes32 conditionId);
    
    // Create direct payment
    function createDirectPayment(
        address recipient,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(recipient != address(0), "Invalid recipient address");
        require(msg.value > 0, "Amount must be greater than 0");
        
        // Register recipient if not already registered
        if (!isRegistered[recipient]) {
            // Create basic profile
            userProfiles[recipient].name = "User";
            userProfiles[recipient].registrationTime = block.timestamp;
            userProfiles[recipient].lastActivityTime = block.timestamp;
            isRegistered[recipient] = true;
        }
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Calculate platform fee
        uint256 platformFeeAmount = (msg.value.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 recipientAmount = msg.value.sub(platformFeeAmount);
        
        // Create new payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = recipient;
        newPayment.amount = msg.value;
        newPayment.paymentType = PaymentType.DIRECT;
        newPayment.status = PaymentStatus.COMPLETED;
        newPayment.creationTime = block.timestamp;
        newPayment.completionTime = block.timestamp;
        newPayment.description = description;
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, recipient, block.timestamp, msg.value));
        
        // Add to user's payments
        userSentPayments[msg.sender].push(newPaymentId);
        userReceivedPayments[recipient].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        // Transfer funds
        userBalances[recipient] = userBalances[recipient].add(recipientAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("payment", newPaymentId));
        createNotification(
            recipient,
            "PAYMENT_RECEIVED",
            entityId,
            string(abi.encodePacked("You received a payment of ", msg.value.toString(), " wei"))
        );
        
        emit PaymentCreated(newPaymentId, msg.sender, recipient, msg.value);
        emit FeePaid(msg.sender, platformFeeAmount, "Payment Fee");
    }
    
    // Create scheduled payment
    function createScheduledPayment(
        address recipient,
        uint256 executeAfter,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(recipient != address(0), "Invalid recipient address");
        require(msg.value > 0, "Amount must be greater than 0");
        require(executeAfter > block.timestamp, "Execution time must be in the future");
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Create new payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = recipient;
        newPayment.amount = msg.value;
        newPayment.paymentType = PaymentType.SCHEDULED;
        newPayment.status = PaymentStatus.PENDING;
        newPayment.creationTime = block.timestamp;
        newPayment.description = description;
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, recipient, block.timestamp, msg.value, executeAfter));
        
        // Create payment condition
        PaymentCondition storage condition = paymentConditions[newPaymentId];
        condition.conditionId = keccak256(abi.encodePacked("time", newPaymentId));
        condition.conditionType = ConditionType.TIME;
        condition.deadline = executeAfter;
        condition.isFulfilled = false;
        condition.verifier = address(this);
        condition.data = abi.encode(executeAfter);
        
        // Add to user's payments
        userSentPayments[msg.sender].push(newPaymentId);
        userReceivedPayments[recipient].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        emit PaymentCreated(newPaymentId, msg.sender, recipient, msg.value);
    }
    
    // Execute scheduled payment
    function executeScheduledPayment(uint256 paymentId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(paymentId > 0 && paymentId <= _paymentIdCounter.current(), "Invalid payment ID");
        
        Payment storage payment = payments[paymentId];
        require(payment.paymentType == PaymentType.SCHEDULED, "Not a scheduled payment");
        require(payment.status == PaymentStatus.PENDING, "Payment not in pending status");
        
        PaymentCondition storage condition = paymentConditions[paymentId];
        require(condition.conditionType == ConditionType.TIME, "Not a time condition");
        require(!condition.isFulfilled, "Condition already fulfilled");
        
        // Check if deadline has passed
        uint256 deadline = abi.decode(condition.data, (uint256));
        require(block.timestamp >= deadline, "Execution time not reached");
        
        // Mark condition as fulfilled
        condition.isFulfilled = true;
        
        // Calculate platform fee
        uint256 platformFeeAmount = (payment.amount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 recipientAmount = payment.amount.sub(platformFeeAmount);
        
        // Update payment status
        payment.status = PaymentStatus.COMPLETED;
        payment.completionTime = block.timestamp;
        
        // Transfer funds
        userBalances[payment.recipient] = userBalances[payment.recipient].add(recipientAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("payment", paymentId));
        createNotification(
            payment.recipient,
            "PAYMENT_RECEIVED",
            entityId,
            string(abi.encodePacked("You received a scheduled payment of ", payment.amount.toString(), " wei"))
        );
        
        emit PaymentStatusChanged(paymentId, PaymentStatus.COMPLETED);
        emit PaymentConditionFulfilled(paymentId, condition.conditionId);
        emit FeePaid(payment.sender, platformFeeAmount, "Payment Fee");
    }
    
    // Cancel scheduled payment
    function cancelScheduledPayment(uint256 paymentId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(paymentId > 0 && paymentId <= _paymentIdCounter.current(), "Invalid payment ID");
        
        Payment storage payment = payments[paymentId];
        require(payment.sender == msg.sender, "Not the payment sender");
        require(payment.paymentType == PaymentType.SCHEDULED, "Not a scheduled payment");
        require(payment.status == PaymentStatus.PENDING, "Payment not in pending status");
        
        PaymentCondition storage condition = paymentConditions[paymentId];
        require(!condition.isFulfilled, "Condition already fulfilled");
        
        // Update payment status
        payment.status = PaymentStatus.CANCELLED;
        
        // Refund sender
        userBalances[msg.sender] = userBalances[msg.sender].add(payment.amount);
        
        emit PaymentStatusChanged(paymentId, PaymentStatus.CANCELLED);
    }
    
    // Create conditional payment
    function createConditionalPayment(
        address recipient,
        ConditionType conditionType,
        address verifier,
        bytes memory conditionData,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(recipient != address(0), "Invalid recipient address");
        require(msg.value > 0, "Amount must be greater than 0");
        require(verifier != address(0), "Invalid verifier address");
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Create new payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = recipient;
        newPayment.amount = msg.value;
        newPayment.paymentType = PaymentType.CONDITIONAL;
        newPayment.status = PaymentStatus.PENDING;
        newPayment.creationTime = block.timestamp;
        newPayment.description = description;
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, recipient, block.timestamp, msg.value, conditionType));
        
        // Create payment condition
        bytes32 conditionId = keccak256(abi.encodePacked(conditionType, newPaymentId, conditionData));
        PaymentCondition storage condition = paymentConditions[newPaymentId];
        condition.conditionId = conditionId;
        condition.conditionType = conditionType;
        condition.deadline = block.timestamp + 30 days; // Default deadline
        condition.isFulfilled = false;
        condition.verifier = verifier;
        condition.data = conditionData;
        
        // Add to user's payments
        userSentPayments[msg.sender].push(newPaymentId);
        userReceivedPayments[recipient].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        emit PaymentCreated(newPaymentId, msg.sender, recipient, msg.value);
    }
    
    // Fulfill conditional payment
    function fulfillConditionalPayment(
        uint256 paymentId,
        bytes memory fulfillmentProof
    ) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(paymentId > 0 && paymentId <= _paymentIdCounter.current(), "Invalid payment ID");
        
        Payment storage payment = payments[paymentId];
        require(payment.paymentType == PaymentType.CONDITIONAL, "Not a conditional payment");
        require(payment.status == PaymentStatus.PENDING, "Payment not in pending status");
        
        PaymentCondition storage condition = paymentConditions[paymentId];
        require(!condition.isFulfilled, "Condition already fulfilled");
        require(block.timestamp <= condition.deadline, "Condition deadline passed");
        
        // Check if caller is the verifier
        require(msg.sender == condition.verifier, "Not the condition verifier");
        
        // Verify fulfillment proof
        bool isValid = false;
        
        if (condition.conditionType == ConditionType.ORACLE) {
            // Oracle verification
            bytes32 dataHash = keccak256(condition.data);
            bytes32 proofHash = keccak256(fulfillmentProof);
            isValid = dataHash == proofHash;
        } else if (condition.conditionType == ConditionType.MULTI_SIG) {
            // Multi-sig verification
            address[] memory signers = abi.decode(condition.data, (address[]));
            address[] memory signatures = abi.decode(fulfillmentProof, (address[]));
            
            // Check if enough signatures provided
            uint256 requiredSignatures = signers.length / 2 + 1; // More than 50%
            isValid = signatures.length >= requiredSignatures;
        } else if (condition.conditionType == ConditionType.EXTERNAL) {
            // External contract verification
            address contractAddress = abi.decode(condition.data, (address));
            isValid = AddressUtils.isContract(contractAddress); // <-- แก้ไขให้เรียกผ่าน AddressUtils
        } else if (condition.conditionType == ConditionType.CUSTOM) {
            // Custom verification
            isValid = true; // Assume valid, rely on verifier's judgment
        } else {
            revert("Unsupported condition type");
        }
        
        require(isValid, "Invalid fulfillment proof");
        
        // Mark condition as fulfilled
        condition.isFulfilled = true;
        
        // Calculate platform fee
        uint256 platformFeeAmount = (payment.amount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 recipientAmount = payment.amount.sub(platformFeeAmount);
        
        // Update payment status
        payment.status = PaymentStatus.COMPLETED;
        payment.completionTime = block.timestamp;
        
        // Transfer funds
        userBalances[payment.recipient] = userBalances[payment.recipient].add(recipientAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("payment", paymentId));
        createNotification(
            payment.recipient,
            "PAYMENT_RECEIVED",
            entityId,
            string(abi.encodePacked("You received a conditional payment of ", payment.amount.toString(), " wei"))
        );
        
        emit PaymentStatusChanged(paymentId, PaymentStatus.COMPLETED);
        emit PaymentConditionFulfilled(paymentId, condition.conditionId);
        emit FeePaid(payment.sender, platformFeeAmount, "Payment Fee");
    }
    
    // Create batch payment
    function createBatchPayment(
        address[] memory recipients,
        uint256[] memory amounts,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(recipients.length)
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "No recipients provided");
        
        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than 0");
            totalAmount = totalAmount.add(amounts[i]);
        }
        
        require(msg.value >= totalAmount, "Insufficient payment amount");
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Create new payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = address(0); // Batch payment has multiple recipients
        newPayment.amount = totalAmount;
        newPayment.paymentType = PaymentType.BATCH;
        newPayment.status = PaymentStatus.COMPLETED;
        newPayment.creationTime = block.timestamp;
        newPayment.completionTime = block.timestamp;
        newPayment.description = description;
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalAmount, "batch"));
        
        // Add to user's sent payments
        userSentPayments[msg.sender].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        // Process each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];
            
            require(recipient != address(0), "Invalid recipient address");
            
            // Register recipient if not already registered
            if (!isRegistered[recipient]) {
                // Create basic profile
                userProfiles[recipient].name = "User";
                userProfiles[recipient].registrationTime = block.timestamp;
                userProfiles[recipient].lastActivityTime = block.timestamp;
                isRegistered[recipient] = true;
            }
            
            // Calculate platform fee
            uint256 platformFeeAmount = (amount.mul(platformFee)).div(FEE_DENOMINATOR);
            uint256 recipientAmount = amount.sub(platformFeeAmount);
            
            // Transfer funds
            userBalances[recipient] = userBalances[recipient].add(recipientAmount);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
            
            // Add to recipient's received payments
            userReceivedPayments[recipient].push(newPaymentId);
            
            // Create notification for recipient
            bytes32 entityId = keccak256(abi.encodePacked("payment", newPaymentId, recipient));
            createNotification(
                recipient,
                "PAYMENT_RECEIVED",
                entityId,
                string(abi.encodePacked("You received a batch payment of ", amount.toString(), " wei"))
            );
            
            emit FeePaid(msg.sender, platformFeeAmount, "Payment Fee");
        }
        
        // Refund excess payment
        if (msg.value > totalAmount) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(totalAmount));
        }
        
        emit PaymentCreated(newPaymentId, msg.sender, address(0), totalAmount);
    }
    
    // Create split payment
    function createSplitPayment(
        address[] memory recipients,
        uint256[] memory percentages,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(recipients.length)
    {
        require(recipients.length == percentages.length, "Arrays length mismatch");
        require(recipients.length > 0, "No recipients provided");
        require(msg.value > 0, "Amount must be greater than 0");
        
        // Calculate total percentage
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < percentages.length; i++) {
            require(percentages[i] > 0, "Percentage must be greater than 0");
            totalPercentage = totalPercentage.add(percentages[i]);
        }
        
        require(totalPercentage == 100, "Total percentage must be 100");
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Create new payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = address(0); // Split payment has multiple recipients
        newPayment.amount = msg.value;
        newPayment.paymentType = PaymentType.SPLIT;
        newPayment.status = PaymentStatus.COMPLETED;
        newPayment.creationTime = block.timestamp;
        newPayment.completionTime = block.timestamp;
        newPayment.description = description;
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, block.timestamp, msg.value, "split"));
        
        // Add to user's sent payments
        userSentPayments[msg.sender].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        // Process each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 percentage = percentages[i];
            
            require(recipient != address(0), "Invalid recipient address");
            
            // Register recipient if not already registered
            if (!isRegistered[recipient]) {
                // Create basic profile
                userProfiles[recipient].name = "User";
                userProfiles[recipient].registrationTime = block.timestamp;
                userProfiles[recipient].lastActivityTime = block.timestamp;
                isRegistered[recipient] = true;
            }
            
            // Calculate amount for this recipient
            uint256 amount = (msg.value.mul(percentage)).div(100);
            
            // Calculate platform fee
            uint256 platformFeeAmount = (amount.mul(platformFee)).div(FEE_DENOMINATOR);
            uint256 recipientAmount = amount.sub(platformFeeAmount);
            
            // Transfer funds
            userBalances[recipient] = userBalances[recipient].add(recipientAmount);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
            
            // Add to recipient's received payments
            userReceivedPayments[recipient].push(newPaymentId);
            
            // Create notification for recipient
            bytes32 entityId = keccak256(abi.encodePacked("payment", newPaymentId, recipient));
            createNotification(
                recipient,
                "PAYMENT_RECEIVED",
                entityId,
                string(abi.encodePacked("You received a split payment of ", amount.toString(), " wei (", percentage.toString(), "%)"))
            );
            
            emit FeePaid(msg.sender, platformFeeAmount, "Payment Fee");
        }
        
        emit PaymentCreated(newPaymentId, msg.sender, address(0), msg.value);
    }
    
    // Create recurring payment (first payment)
    function createRecurringPayment(
        address recipient,
        uint256 intervalSeconds,
        uint256 numberOfPayments,
        string memory description
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(recipient != address(0), "Invalid recipient address");
        require(msg.value > 0, "Amount must be greater than 0");
        require(intervalSeconds > 0, "Interval must be greater than 0");
        require(numberOfPayments > 1, "Number of payments must be greater than 1");
        
        // Total amount needed for all payments
        uint256 totalAmount = msg.value.mul(numberOfPayments);
        
        // Check if user has enough balance for all payments
        require(userBalances[msg.sender] >= totalAmount.sub(msg.value), "Insufficient balance for all payments");
        
        // Increment payment ID counter
        _paymentIdCounter.increment();
        uint256 newPaymentId = _paymentIdCounter.current();
        
        // Calculate platform fee for first payment
        uint256 platformFeeAmount = (msg.value.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 recipientAmount = msg.value.sub(platformFeeAmount);
        
        // Create new payment for first payment
        Payment storage newPayment = payments[newPaymentId];
        newPayment.id = newPaymentId;
        newPayment.sender = msg.sender;
        newPayment.recipient = recipient;
        newPayment.amount = msg.value;
        newPayment.paymentType = PaymentType.RECURRING;
        newPayment.status = PaymentStatus.COMPLETED;
        newPayment.creationTime = block.timestamp;
        newPayment.completionTime = block.timestamp;
        newPayment.description = string(abi.encodePacked(description, " (1/", uint256(numberOfPayments).toString(), ")"));
        newPayment.referenceId = keccak256(abi.encodePacked(msg.sender, recipient, block.timestamp, msg.value, "recurring"));
        
        // Add to user's payments
        userSentPayments[msg.sender].push(newPaymentId);
        userReceivedPayments[recipient].push(newPaymentId);
        
        // Add reference mapping
        referenceToPaymentId[newPayment.referenceId] = newPaymentId;
        
        // Transfer funds for first payment
        userBalances[recipient] = userBalances[recipient].add(recipientAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("payment", newPaymentId));
        createNotification(
            recipient,
            "PAYMENT_RECEIVED",
            entityId,
            string(abi.encodePacked("You received a recurring payment of ", msg.value.toString(), " wei (1/", uint256(numberOfPayments).toString(), ")"))
        );
        
        // Create scheduled payments for remaining payments
        for (uint256 i = 1; i < numberOfPayments; i++) {
            uint256 executeAfter = block.timestamp + (intervalSeconds * i);
            
            // Increment payment ID counter
            _paymentIdCounter.increment();
            uint256 scheduledPaymentId = _paymentIdCounter.current();
            
            // Create new payment for scheduled payment
            Payment storage scheduledPayment = payments[scheduledPaymentId];
            scheduledPayment.id = scheduledPaymentId;
            scheduledPayment.sender = msg.sender;
            scheduledPayment.recipient = recipient;
            scheduledPayment.amount = msg.value;
            scheduledPayment.paymentType = PaymentType.SCHEDULED;
            scheduledPayment.status = PaymentStatus.PENDING;
            scheduledPayment.creationTime = block.timestamp;
            scheduledPayment.description = string(abi.encodePacked(description, " (", uint256(i + 1).toString(), "/", uint256(numberOfPayments).toString(), ")"));
            scheduledPayment.referenceId = keccak256(abi.encodePacked(msg.sender, recipient, block.timestamp, msg.value, "recurring", i));
            
            // Create payment condition
            PaymentCondition storage condition = paymentConditions[scheduledPaymentId];
            condition.conditionId = keccak256(abi.encodePacked("time", scheduledPaymentId));
            condition.conditionType = ConditionType.TIME;
            condition.deadline = executeAfter;
            condition.isFulfilled = false;
            condition.verifier = address(this);
            condition.data = abi.encode(executeAfter);
            
            // Add to user's payments
            userSentPayments[msg.sender].push(scheduledPaymentId);
            userReceivedPayments[recipient].push(scheduledPaymentId);
            
            // Add reference mapping
            referenceToPaymentId[scheduledPayment.referenceId] = scheduledPaymentId;
            
            emit PaymentCreated(scheduledPaymentId, msg.sender, recipient, msg.value);
        }
        
        // Reserve funds for future payments
        userBalances[msg.sender] = userBalances[msg.sender].sub(totalAmount.sub(msg.value));
        
        emit PaymentCreated(newPaymentId, msg.sender, recipient, msg.value);
        emit FeePaid(msg.sender, platformFeeAmount, "Payment Fee");
    }
    
    // Get payment details
    function getPaymentDetails(uint256 paymentId) 
        external 
        view 
        returns (
            address sender,
            address recipient,
            uint256 amount,
            PaymentType paymentType,
            PaymentStatus status,
            uint256 creationTime,
            uint256 completionTime,
            string memory description
        ) 
    {
        require(paymentId > 0 && paymentId <= _paymentIdCounter.current(), "Invalid payment ID");
        
        Payment storage payment = payments[paymentId];
        
        return (
            payment.sender,
            payment.recipient,
            payment.amount,
            payment.paymentType,
            payment.status,
            payment.creationTime,
            payment.completionTime,
            payment.description
        );
    }
    
    // Get payment condition details
    function getPaymentConditionDetails(uint256 paymentId) 
        external 
        view 
        returns (
            bytes32 conditionId,
            ConditionType conditionType,
            uint256 deadline,
            bool isFulfilled,
            address verifier
        ) 
    {
        require(paymentId > 0 && paymentId <= _paymentIdCounter.current(), "Invalid payment ID");
        
        PaymentCondition storage condition = paymentConditions[paymentId];
        
        return (
            condition.conditionId,
            condition.conditionType,
            condition.deadline,
            condition.isFulfilled,
            condition.verifier
        );
    }
    
    // Get user sent payments
    function getUserSentPayments(address user, uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory sentPayments = userSentPayments[user];
        
        if (offset >= sentPayments.length) {
            return new uint256[](0);
        }
        
        uint256 size = limit;
        if (offset + limit > sentPayments.length) {
            size = sentPayments.length - offset;
        }
        
        uint256[] memory result = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = sentPayments[offset + i];
        }
        
        return result;
    }
    
    // Get user received payments
    function getUserReceivedPayments(address user, uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory receivedPayments = userReceivedPayments[user];
        
        if (offset >= receivedPayments.length) {
            return new uint256[](0);
        }
        
        uint256 size = limit;
        if (offset + limit > receivedPayments.length) {
            size = receivedPayments.length - offset;
        }
        
        uint256[] memory result = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = receivedPayments[offset + i];
        }
        
        return result;
    }
    
    // Get payment by reference ID
    function getPaymentByReferenceId(bytes32 referenceId) 
        external 
        view 
        returns (uint256) 
    {
        return referenceToPaymentId[referenceId];
    }
    
    // ==================== ESCROW SYSTEM ====================
    
    // Structure for escrow
    struct Escrow {
        uint256 id;
        address buyer;
        address seller;
        uint256 amount;
        EscrowStatus status;
        uint256 creationTime;
        uint256 completionTime;
        uint256 expirationTime;
        string description;
        bytes32 itemId;
    }
    
    // Enum for escrow status
    enum EscrowStatus { CREATED, FUNDED, RELEASED, REFUNDED, DISPUTED, RESOLVED }
    
    // Mapping for escrows
    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public userBuyerEscrows;
    mapping(address => uint256[]) public userSellerEscrows;
    mapping(bytes32 => uint256) public itemToEscrowId;
    
    // Counter for escrows
    Counters.Counter private _escrowIdCounter;
    
    // Events for escrows
    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 amount);
    event EscrowFunded(uint256 indexed escrowId, uint256 amount);
    event EscrowReleased(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);
    event EscrowDisputed(uint256 indexed escrowId);
    event EscrowResolved(uint256 indexed escrowId, address indexed winner);
    
    // Create escrow
    function createEscrow(
        address seller,
        uint256 expirationTime,
        string memory description,
        bytes32 itemId
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(seller != address(0), "Invalid seller address");
        require(seller != msg.sender, "Cannot create escrow for self");
        require(msg.value > 0, "Amount must be greater than 0");
        require(expirationTime > block.timestamp, "Expiration time must be in the future");
        require(itemId != bytes32(0), "Invalid item ID");
        
        // Register seller if not already registered
        if (!isRegistered[seller]) {
            // Create basic profile
            userProfiles[seller].name = "Seller";
            userProfiles[seller].registrationTime = block.timestamp;
            userProfiles[seller].lastActivityTime = block.timestamp;
            isRegistered[seller] = true;
        }
        
        // Increment escrow ID counter
        _escrowIdCounter.increment();
        uint256 newEscrowId = _escrowIdCounter.current();
        
        // Create new escrow
        Escrow storage newEscrow = escrows[newEscrowId];
        newEscrow.id = newEscrowId;
        newEscrow.buyer = msg.sender;
        newEscrow.seller = seller;
        newEscrow.amount = msg.value;
        newEscrow.status = EscrowStatus.FUNDED;
        newEscrow.creationTime = block.timestamp;
        newEscrow.expirationTime = expirationTime;
        newEscrow.description = description;
        newEscrow.itemId = itemId;
        
        // Add to user's escrows
        userBuyerEscrows[msg.sender].push(newEscrowId);
        userSellerEscrows[seller].push(newEscrowId);
        
        // Add item to escrow mapping
        itemToEscrowId[itemId] = newEscrowId;
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("escrow", newEscrowId));
        createNotification(
            seller,
            "ESCROW_CREATED",
            entityId,
            string(abi.encodePacked("A new escrow was created for you with amount: ", msg.value.toString(), " wei"))
        );
        
        emit EscrowCreated(newEscrowId, msg.sender, seller, msg.value);
        emit EscrowFunded(newEscrowId, msg.value);
    }
    
    // Release escrow funds to seller
    function releaseEscrow(uint256 escrowId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        require(escrow.buyer == msg.sender, "Not the escrow buyer");
        require(escrow.status == EscrowStatus.FUNDED, "Escrow not in funded status");
        require(block.timestamp <= escrow.expirationTime, "Escrow expired");
        
        // Calculate platform fee
        uint256 platformFeeAmount = (escrow.amount.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 sellerAmount = escrow.amount.sub(platformFeeAmount);
        
        // Update escrow status
        escrow.status = EscrowStatus.RELEASED;
        escrow.completionTime = block.timestamp;
        
        // Transfer funds
        userBalances[escrow.seller] = userBalances[escrow.seller].add(sellerAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "release"));
        createNotification(
            escrow.seller,
            "ESCROW_RELEASED",
            entityId,
            string(abi.encodePacked("Escrow funds of ", sellerAmount.toString(), " wei have been released to you"))
        );
        
        emit EscrowReleased(escrowId);
        emit FeePaid(escrow.buyer, platformFeeAmount, "Escrow Fee");
    }
    
    // Refund escrow to buyer
    function refundEscrow(uint256 escrowId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        require(escrow.seller == msg.sender, "Not the escrow seller");
        require(escrow.status == EscrowStatus.FUNDED, "Escrow not in funded status");
        
        // Update escrow status
        escrow.status = EscrowStatus.REFUNDED;
        escrow.completionTime = block.timestamp;
        
        // Transfer funds back to buyer
        userBalances[escrow.buyer] = userBalances[escrow.buyer].add(escrow.amount);
        
        // Create notification for buyer
        bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "refund"));
        createNotification(
            escrow.buyer,
            "ESCROW_REFUNDED",
            entityId,
            string(abi.encodePacked("Escrow funds of ", escrow.amount.toString(), " wei have been refunded to you"))
        );
        
        emit EscrowRefunded(escrowId);
    }
    
    // Dispute escrow
    function disputeEscrow(uint256 escrowId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        require(escrow.buyer == msg.sender || escrow.seller == msg.sender, "Not a party to the escrow");
        require(escrow.status == EscrowStatus.FUNDED, "Escrow not in funded status");
        
        // Update escrow status
        escrow.status = EscrowStatus.DISPUTED;
        
        // Create notification for other party
        address otherParty = (msg.sender == escrow.buyer) ? escrow.seller : escrow.buyer;
        bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "dispute"));
        createNotification(
            otherParty,
            "ESCROW_DISPUTED",
            entityId,
            string(abi.encodePacked("Escrow with ID ", uint256(escrowId).toString(), " has been disputed"))
        );
        
        // Create notification for owner to resolve
        createNotification(
            owner(),
            "ESCROW_DISPUTED",
            entityId,
            string(abi.encodePacked("Escrow with ID ", uint256(escrowId).toString(), " has been disputed"))
        );
        
        emit EscrowDisputed(escrowId);
    }
    
    // Resolve disputed escrow (owner only)
    function resolveEscrow(uint256 escrowId, address winner) 
        external 
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.DISPUTED, "Escrow not in disputed status");
        require(winner == escrow.buyer || winner == escrow.seller, "Winner must be buyer or seller");
        
        // Update escrow status
        escrow.status = EscrowStatus.RESOLVED;
        escrow.completionTime = block.timestamp;
        
        if (winner == escrow.seller) {
            // Calculate platform fee
            uint256 platformFeeAmount = (escrow.amount.mul(platformFee)).div(FEE_DENOMINATOR);
            uint256 sellerAmount = escrow.amount.sub(platformFeeAmount);
            
            // Transfer funds to seller
            userBalances[escrow.seller] = userBalances[escrow.seller].add(sellerAmount);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
            
            // Create notification for seller
            bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "resolve", "seller"));
            createNotification(
                escrow.seller,
                "ESCROW_RESOLVED",
                entityId,
                string(abi.encodePacked("Escrow dispute resolved in your favor. You received ", sellerAmount.toString(), " wei"))
            );
            
            // Create notification for buyer
            bytes32 entityId2 = keccak256(abi.encodePacked("escrow", escrowId, "resolve", "buyer"));
            createNotification(
                escrow.buyer,
                "ESCROW_RESOLVED",
                entityId2,
                string(abi.encodePacked("Escrow dispute resolved in favor of the seller"))
            );
            
            emit FeePaid(escrow.buyer, platformFeeAmount, "Escrow Fee");
        } else {
            // Transfer funds back to buyer
            userBalances[escrow.buyer] = userBalances[escrow.buyer].add(escrow.amount);
            
            // Create notification for buyer
            bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "resolve", "buyer"));
            createNotification(
                escrow.buyer,
                "ESCROW_RESOLVED",
                entityId,
                string(abi.encodePacked("Escrow dispute resolved in your favor. You received ", escrow.amount.toString(), " wei"))
            );
            
            // Create notification for seller
            bytes32 entityId2 = keccak256(abi.encodePacked("escrow", escrowId, "resolve", "seller"));
            createNotification(
                escrow.seller,
                "ESCROW_RESOLVED",
                entityId2,
                string(abi.encodePacked("Escrow dispute resolved in favor of the buyer"))
            );
        }
        
        emit EscrowResolved(escrowId, winner);
    }
    
    // Claim expired escrow
    function claimExpiredEscrow(uint256 escrowId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        require(escrow.buyer == msg.sender, "Not the escrow buyer");
        require(escrow.status == EscrowStatus.FUNDED, "Escrow not in funded status");
        require(block.timestamp > escrow.expirationTime, "Escrow not expired");
        
        // Update escrow status
        escrow.status = EscrowStatus.REFUNDED;
        escrow.completionTime = block.timestamp;
        
        // Transfer funds back to buyer
        userBalances[escrow.buyer] = userBalances[escrow.buyer].add(escrow.amount);
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("escrow", escrowId, "expired"));
        createNotification(
            escrow.seller,
            "ESCROW_EXPIRED",
            entityId,
            string(abi.encodePacked("Escrow with ID ", uint256(escrowId).toString(), " has expired and been refunded to the buyer"))
        );
        
        emit EscrowRefunded(escrowId);
    }
    
    // Get escrow details
    function getEscrowDetails(uint256 escrowId) 
        external 
        view 
        returns (
            address buyer,
            address seller,
            uint256 amount,
            EscrowStatus status,
            uint256 creationTime,
            uint256 completionTime,
            uint256 expirationTime,
            string memory description,
            bytes32 itemId
        ) 
    {
        require(escrowId > 0 && escrowId <= _escrowIdCounter.current(), "Invalid escrow ID");
        
        Escrow storage escrow = escrows[escrowId];
        
        return (
            escrow.buyer,
            escrow.seller,
            escrow.amount,
            escrow.status,
            escrow.creationTime,
            escrow.completionTime,
            escrow.expirationTime,
            escrow.description,
            escrow.itemId
        );
    }
    
    // Get user buyer escrows
    function getUserBuyerEscrows(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userBuyerEscrows[user];
    }
    
    // Get user seller escrows
    function getUserSellerEscrows(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userSellerEscrows[user];
    }
    
    // Get escrow by item ID
    function getEscrowByItemId(bytes32 itemId) 
        external 
        view 
        returns (uint256) 
    {
        return itemToEscrowId[itemId];
    }
    
    // ==================== SUBSCRIPTION SYSTEM ====================
    
    // Structure for subscription plan
    struct SubscriptionPlan {
        uint256 id;
        string name;
        string description;
        address creator;
        uint256 price;
        uint256 durationSeconds;
        uint256 creationTime;
        bool isActive;
        uint256 subscriberCount;
        bytes32 planHash;
    }
    
    // Structure for subscription
    struct Subscription {
        uint256 id;
        uint256 planId;
        address subscriber;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool autoRenew;
        uint256 lastRenewalTime;
        uint256 renewalCount;
    }
    
    // Mapping for subscription plans and subscriptions
    mapping(uint256 => SubscriptionPlan) public subscriptionPlans;
    mapping(bytes32 => uint256) public planHashToPlanId;
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;
    mapping(address => uint256[]) public creatorSubscriptionPlans;
    
    // Counter for subscription plans and subscriptions
    Counters.Counter private _subscriptionPlanIdCounter;
    Counters.Counter private _subscriptionIdCounter;
    
    // Events for subscriptions
    event SubscriptionPlanCreated(uint256 indexed planId, address indexed creator, string name, uint256 price);
    event SubscriptionCreated(uint256 indexed subscriptionId, uint256 indexed planId, address indexed subscriber);
    event SubscriptionRenewed(uint256 indexed subscriptionId, uint256 newEndTime);
    event SubscriptionCancelled(uint256 indexed subscriptionId);
    
    // Create subscription plan
    function createSubscriptionPlan(
        string memory name,
        string memory description,
        uint256 price,
        uint256 durationSeconds
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(price > 0, "Price must be greater than 0");
        require(durationSeconds > 0, "Duration must be greater than 0");
        
        // Calculate plan hash
        bytes32 planHash = keccak256(abi.encodePacked(msg.sender, name, price, durationSeconds));
        
        // Check if plan already exists
        require(planHashToPlanId[planHash] == 0, "Plan already exists");
        
        // Increment subscription plan ID counter
        _subscriptionPlanIdCounter.increment();
        uint256 newPlanId = _subscriptionPlanIdCounter.current();
        
        // Create new subscription plan
        SubscriptionPlan storage newPlan = subscriptionPlans[newPlanId];
        newPlan.id = newPlanId;
        newPlan.name = name;
        newPlan.description = description;
        newPlan.creator = msg.sender;
        newPlan.price = price;
        newPlan.durationSeconds = durationSeconds;
        newPlan.creationTime = block.timestamp;
        newPlan.isActive = true;
        newPlan.subscriberCount = 0;
        newPlan.planHash = planHash;
        
        // Add to mappings
        planHashToPlanId[planHash] = newPlanId;
        creatorSubscriptionPlans[msg.sender].push(newPlanId);
        
        emit SubscriptionPlanCreated(newPlanId, msg.sender, name, price);
    }
    
    // Update subscription plan
    function updateSubscriptionPlan(
        uint256 planId,
        string memory description,
        uint256 price,
        bool isActive
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(planId > 0 && planId <= _subscriptionPlanIdCounter.current(), "Invalid plan ID");
        
        SubscriptionPlan storage plan = subscriptionPlans[planId];
        require(plan.creator == msg.sender, "Not the plan creator");
        require(price > 0, "Price must be greater than 0");
        
        // Update plan
        plan.description = description;
        plan.price = price;
        plan.isActive = isActive;
        
        emit SubscriptionPlanCreated(planId, msg.sender, plan.name, price);
    }
    
    // Subscribe to plan
    function subscribe(
        uint256 planId,
        bool autoRenew
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(planId > 0 && planId <= _subscriptionPlanIdCounter.current(), "Invalid plan ID");
        
        SubscriptionPlan storage plan = subscriptionPlans[planId];
        require(plan.isActive, "Plan not active");
        require(msg.value >= plan.price, "Insufficient payment");
        
        // Check if user already has an active subscription to this plan
        for (uint256 i = 0; i < userSubscriptions[msg.sender].length; i++) {
            uint256 subId = userSubscriptions[msg.sender][i];
            Subscription storage existingSub = subscriptions[subId];
            
            if (existingSub.planId == planId && existingSub.isActive && existingSub.endTime > block.timestamp) {
                // Extend existing subscription
                uint256 newEndTime = existingSub.endTime + plan.durationSeconds;
                existingSub.endTime = newEndTime;
                existingSub.autoRenew = autoRenew;
                existingSub.lastRenewalTime = block.timestamp;
                existingSub.renewalCount += 1;
                
                // Calculate platform fee
                uint256 platformFeeAmount = (plan.price.mul(platformFee)).div(FEE_DENOMINATOR);
                uint256 creatorAmount = plan.price.sub(platformFeeAmount);
                
                // Transfer funds
                userBalances[plan.creator] = userBalances[plan.creator].add(creatorAmount);
                userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
                
                // Refund excess payment
                if (msg.value > plan.price) {
                    userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(plan.price));
                }
                
                // Create notification for subscriber
                bytes32 entityId = keccak256(abi.encodePacked("subscription", subId, "renewed"));
                createNotification(
                    msg.sender,
                    "SUBSCRIPTION_RENEWED",
                    entityId,
                    string(abi.encodePacked("Your subscription to ", plan.name, " has been renewed until ", uint256(newEndTime).toString()))
                );
                
                emit SubscriptionRenewed(subId, newEndTime);
                emit FeePaid(msg.sender, platformFeeAmount, "Subscription Fee");
                
                return;
            }
        }
        
        // Create new subscription
        _subscriptionIdCounter.increment();
        uint256 newSubscriptionId = _subscriptionIdCounter.current();
        
        // Calculate start and end times
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + plan.durationSeconds;
        
        // Create new subscription
        Subscription storage newSubscription = subscriptions[newSubscriptionId];
        newSubscription.id = newSubscriptionId;
        newSubscription.planId = planId;
        newSubscription.subscriber = msg.sender;
        newSubscription.startTime = startTime;
        newSubscription.endTime = endTime;
        newSubscription.isActive = true;
        newSubscription.autoRenew = autoRenew;
        newSubscription.lastRenewalTime = startTime;
        newSubscription.renewalCount = 0;
        
        // Update plan subscriber count
        plan.subscriberCount += 1;
        
        // Add to user's subscriptions
        userSubscriptions[msg.sender].push(newSubscriptionId);
        
        // Calculate platform fee
        uint256 platformFeeAmount = (plan.price.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 creatorAmount = plan.price.sub(platformFeeAmount);
        
        // Transfer funds
        userBalances[plan.creator] = userBalances[plan.creator].add(creatorAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Refund excess payment
        if (msg.value > plan.price) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(plan.price));
        }
        
        // Create notification for creator
        bytes32 entityId1 = keccak256(abi.encodePacked("subscription", newSubscriptionId, "creator"));
        createNotification(
            plan.creator,
            "NEW_SUBSCRIBER",
            entityId1,
            string(abi.encodePacked("New subscriber to your plan: ", plan.name))
        );
        
        // Create notification for subscriber
        bytes32 entityId2 = keccak256(abi.encodePacked("subscription", newSubscriptionId, "subscriber"));
        createNotification(
            msg.sender,
            "SUBSCRIPTION_CREATED",
            entityId2,
            string(abi.encodePacked("You are now subscribed to ", plan.name, " until ", uint256(endTime).toString()))
        );
        
        emit SubscriptionCreated(newSubscriptionId, planId, msg.sender);
        emit FeePaid(msg.sender, platformFeeAmount, "Subscription Fee");
    }
    
    // Renew subscription
    function renewSubscription(uint256 subscriptionId) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(subscriptionId > 0 && subscriptionId <= _subscriptionIdCounter.current(), "Invalid subscription ID");
        
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.subscriber == msg.sender, "Not the subscriber");
        
        SubscriptionPlan storage plan = subscriptionPlans[subscription.planId];
        require(plan.isActive, "Plan not active");
        require(msg.value >= plan.price, "Insufficient payment");
        
        // Calculate new end time
        uint256 newEndTime;
        if (subscription.endTime > block.timestamp) {
            // Extend current subscription
            newEndTime = subscription.endTime + plan.durationSeconds;
        } else {
            // Start new period
            newEndTime = block.timestamp + plan.durationSeconds;
        }
        
        // Update subscription
        subscription.endTime = newEndTime;
        subscription.isActive = true;
        subscription.lastRenewalTime = block.timestamp;
        subscription.renewalCount += 1;
        
        // Calculate platform fee
        uint256 platformFeeAmount = (plan.price.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 creatorAmount = plan.price.sub(platformFeeAmount);
        
        // Transfer funds
        userBalances[plan.creator] = userBalances[plan.creator].add(creatorAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Refund excess payment
        if (msg.value > plan.price) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(plan.price));
        }
        
        // Create notification for subscriber
        bytes32 entityId = keccak256(abi.encodePacked("subscription", subscriptionId, "renewed"));
        createNotification(
            msg.sender,
            "SUBSCRIPTION_RENEWED",
            entityId,
            string(abi.encodePacked("Your subscription to ", plan.name, " has been renewed until ", uint256(newEndTime).toString()))
        );
        
        emit SubscriptionRenewed(subscriptionId, newEndTime);
        emit FeePaid(msg.sender, platformFeeAmount, "Subscription Fee");
    }
    
    // Cancel subscription
    function cancelSubscription(uint256 subscriptionId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(subscriptionId > 0 && subscriptionId <= _subscriptionIdCounter.current(), "Invalid subscription ID");
        
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.subscriber == msg.sender, "Not the subscriber");
        require(subscription.isActive, "Subscription not active");
        
        // Update subscription
        subscription.isActive = false;
        subscription.autoRenew = false;
        
        SubscriptionPlan storage plan = subscriptionPlans[subscription.planId];
        
        // Update plan subscriber count
        if (plan.subscriberCount > 0) {
            plan.subscriberCount -= 1;
        }
        
        // Create notification for creator
        bytes32 entityId1 = keccak256(abi.encodePacked("subscription", subscriptionId, "cancelled", "creator"));
        createNotification(
            plan.creator,
            "SUBSCRIPTION_CANCELLED",
            entityId1,
            string(abi.encodePacked("A subscriber has cancelled their subscription to ", plan.name))
        );
        
        // Create notification for subscriber
        bytes32 entityId2 = keccak256(abi.encodePacked("subscription", subscriptionId, "cancelled", "subscriber"));
        createNotification(
            msg.sender,
            "SUBSCRIPTION_CANCELLED",
            entityId2,
            string(abi.encodePacked("You have cancelled your subscription to ", plan.name))
        );
        
        emit SubscriptionCancelled(subscriptionId);
    }
    
    // Check if subscription is active
    function isSubscriptionActive(uint256 subscriptionId) 
        external 
        view 
        returns (bool) 
    {
        require(subscriptionId > 0 && subscriptionId <= _subscriptionIdCounter.current(), "Invalid subscription ID");
        
        Subscription storage subscription = subscriptions[subscriptionId];
        return subscription.isActive && subscription.endTime > block.timestamp;
    }
    
    // Get subscription plan details
    function getSubscriptionPlanDetails(uint256 planId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address creator,
            uint256 price,
            uint256 durationSeconds,
            bool isActive,
            uint256 subscriberCount
        ) 
    {
        require(planId > 0 && planId <= _subscriptionPlanIdCounter.current(), "Invalid plan ID");
        
        SubscriptionPlan storage plan = subscriptionPlans[planId];
        
        return (
            plan.name,
            plan.description,
            plan.creator,
            plan.price,
            plan.durationSeconds,
            plan.isActive,
            plan.subscriberCount
        );
    }
    
    // Get subscription details
    function getSubscriptionDetails(uint256 subscriptionId) 
        external 
        view 
        returns (
            uint256 planId,
            address subscriber,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            bool autoRenew,
            uint256 lastRenewalTime,
            uint256 renewalCount
        ) 
    {
        require(subscriptionId > 0 && subscriptionId <= _subscriptionIdCounter.current(), "Invalid subscription ID");
        
        Subscription storage subscription = subscriptions[subscriptionId];
        
        return (
            subscription.planId,
            subscription.subscriber,
            subscription.startTime,
            subscription.endTime,
            subscription.isActive,
            subscription.autoRenew,
            subscription.lastRenewalTime,
            subscription.renewalCount
        );
    }
    
    // Get user subscriptions
    function getUserSubscriptions(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userSubscriptions[user];
    }
    
    // Get creator subscription plans
    function getCreatorSubscriptionPlans(address creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return creatorSubscriptionPlans[creator];
    }
    
    // ==================== CROWDFUNDING SYSTEM ====================
    
    // Structure for crowdfunding campaign
    struct CrowdfundingCampaign {
        uint256 id;
        string name;
        string description;
        address creator;
        uint256 goal;
        uint256 raised;
        uint256 creationTime;
        uint256 deadline;
        bool isClosed;
        bool isSuccessful;
        CampaignCategory category;
        string imageURI;
        uint256 backerCount;
        uint256[] milestones;
        uint256 currentMilestone;
    }
    
    // Structure for campaign contribution
    struct CampaignContribution {
        uint256 campaignId;
        address backer;
        uint256 amount;
        uint256 timestamp;
        bool isRefunded;
    }
    
    // Enum for campaign category
    enum CampaignCategory { TECHNOLOGY, CREATIVE, COMMUNITY, CHARITY, BUSINESS, OTHER }
    
    // Mapping for crowdfunding campaigns
    mapping(uint256 => CrowdfundingCampaign) public crowdfundingCampaigns;
    mapping(uint256 => mapping(address => CampaignContribution)) public campaignContributions;
    mapping(uint256 => address[]) public campaignBackers;
    mapping(address => uint256[]) public userCreatedCampaigns;
    mapping(address => uint256[]) public userBackedCampaigns;
    
    // Counter for crowdfunding campaigns
    Counters.Counter private _campaignIdCounter;
    
    // Events for crowdfunding
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event CampaignContributed(uint256 indexed campaignId, address indexed backer, uint256 amount);
    event CampaignClosed(uint256 indexed campaignId, bool isSuccessful, uint256 raised);
    event CampaignFundsClaimed(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event CampaignContributionRefunded(uint256 indexed campaignId, address indexed backer, uint256 amount);
    event CampaignMilestoneReached(uint256 indexed campaignId, uint256 milestoneIndex);
    
    // Create crowdfunding campaign
    function createCrowdfundingCampaign(
        string memory name,
        string memory description,
        uint256 goal,
        uint256 durationDays,
        CampaignCategory category,
        string memory imageURI,
        uint256[] memory milestones
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(goal > 0, "Goal must be greater than 0");
        require(durationDays > 0 && durationDays <= 180, "Duration must be between 1 and 180 days");
        require(milestones.length <= 10, "Too many milestones");
        
        // Validate milestones
        if (milestones.length > 0) {
            for (uint256 i = 0; i < milestones.length; i++) {
                require(milestones[i] > 0 && milestones[i] <= goal, "Invalid milestone amount");
                
                if (i > 0) {
                    require(milestones[i] > milestones[i-1], "Milestones must be in ascending order");
                }
            }
        }
        
        // Calculate deadline
        uint256 deadline = block.timestamp + (durationDays * 1 days);
        
        // Increment campaign ID counter
        _campaignIdCounter.increment();
        uint256 newCampaignId = _campaignIdCounter.current();
        
        // Create new campaign
        CrowdfundingCampaign storage newCampaign = crowdfundingCampaigns[newCampaignId];
        newCampaign.id = newCampaignId;
        newCampaign.name = name;
        newCampaign.description = description;
        newCampaign.creator = msg.sender;
        newCampaign.goal = goal;
        newCampaign.raised = 0;
        newCampaign.creationTime = block.timestamp;
        newCampaign.deadline = deadline;
        newCampaign.isClosed = false;
        newCampaign.isSuccessful = false;
        newCampaign.category = category;
        newCampaign.imageURI = imageURI;
        newCampaign.backerCount = 0;
        newCampaign.currentMilestone = 0;
        
        // Add milestones
        for (uint256 i = 0; i < milestones.length; i++) {
            newCampaign.milestones.push(milestones[i]);
        }
        
        // Add to user's created campaigns
        userCreatedCampaigns[msg.sender].push(newCampaignId);
        
        // Pay creation fee
        uint256 creationFee = 0.01 ether;
        require(userBalances[msg.sender] >= creationFee, "Insufficient balance for creation fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(creationFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(creationFee);
        
        emit FeePaid(msg.sender, creationFee, "Campaign Creation");
        emit CampaignCreated(newCampaignId, msg.sender, goal, deadline);
    }
    
    // Contribute to campaign
    function contributeToCampaign(uint256 campaignId) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        require(msg.value > 0, "Contribution must be greater than 0");
        
        CrowdfundingCampaign storage campaign = crowdfundingCampaigns[campaignId];
        require(!campaign.isClosed, "Campaign is closed");
        require(block.timestamp <= campaign.deadline, "Campaign has ended");
        
        // Check if first contribution from this backer
        bool isNewBacker = false;
        if (campaignContributions[campaignId][msg.sender].timestamp == 0) {
            isNewBacker = true;
            campaign.backerCount += 1;
            campaignBackers[campaignId].push(msg.sender);
            
            // Add to user's backed campaigns
            userBackedCampaigns[msg.sender].push(campaignId);
        }
        
        // Update or create contribution
        CampaignContribution storage contribution = campaignContributions[campaignId][msg.sender];
        
        if (!isNewBacker) {
            // Add to existing contribution
            contribution.amount = contribution.amount.add(msg.value);
            contribution.timestamp = block.timestamp;
        } else {
            // Create new contribution
            contribution.campaignId = campaignId;
            contribution.backer = msg.sender;
            contribution.amount = msg.value;
            contribution.timestamp = block.timestamp;
            contribution.isRefunded = false;
        }
        
        // Update campaign raised amount
        campaign.raised = campaign.raised.add(msg.value);
        
        // Check if any milestones reached
        if (campaign.milestones.length > 0) {
            for (uint256 i = campaign.currentMilestone; i < campaign.milestones.length; i++) {
                if (campaign.raised >= campaign.milestones[i]) {
                    campaign.currentMilestone = i + 1;
                    
                    // Create notification for campaign creator
                    bytes32 entityId = keccak256(abi.encodePacked("campaign", campaignId, "milestone", i));
                    createNotification(
                        campaign.creator,
                        "CAMPAIGN_MILESTONE_REACHED",
                        entityId,
                        string(abi.encodePacked("Your campaign has reached milestone ", uint256(i + 1).toString(), " of ", uint256(campaign.milestones.length).toString()))
                    );
                    
                    emit CampaignMilestoneReached(campaignId, i);
                }
            }
        }
        
        // Check if goal reached
        if (campaign.raised >= campaign.goal && !campaign.isSuccessful) {
            campaign.isSuccessful = true;
            
            // Create notification for campaign creator
            bytes32 entityId = keccak256(abi.encodePacked("campaign", campaignId, "goal"));
            createNotification(
                campaign.creator,
                "CAMPAIGN_GOAL_REACHED",
                entityId,
                string(abi.encodePacked("Your campaign has reached its funding goal of ", campaign.goal.toString(), " wei"))
            );
        }
        
        // Create notification for campaign creator
        bytes32 entityId = keccak256(abi.encodePacked("campaign", campaignId, "contribution", msg.sender));
        createNotification(
            campaign.creator,
            "CAMPAIGN_CONTRIBUTION",
            entityId,
            string(abi.encodePacked("Your campaign received a contribution of ", msg.value.toString(), " wei"))
        );
        
        emit CampaignContributed(campaignId, msg.sender, msg.value);
    }
    
    // Close campaign
    function closeCampaign(uint256 campaignId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        CrowdfundingCampaign storage campaign = crowdfundingCampaigns[campaignId];
        require(!campaign.isClosed, "Campaign already closed");
        
        // Check if caller is campaign creator or if deadline has passed
        require(
            campaign.creator == msg.sender || block.timestamp > campaign.deadline,
            "Only creator can close before deadline"
        );
        
        // Update campaign status
        campaign.isClosed = true;
        
        emit CampaignClosed(campaignId, campaign.isSuccessful, campaign.raised);
    }
    
    // Claim campaign funds
    function claimCampaignFunds(uint256 campaignId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        CrowdfundingCampaign storage campaign = crowdfundingCampaigns[campaignId];
        require(campaign.creator == msg.sender, "Not the campaign creator");
        require(campaign.isClosed || block.timestamp > campaign.deadline, "Campaign not closed");
        require(campaign.raised > 0, "No funds to claim");
        
        // Different rules depending on success
        if (campaign.raised >= campaign.goal) {
            // Successful campaign - creator gets funds
            campaign.isSuccessful = true;
            
            // Calculate platform fee
            uint256 platformFeeAmount = (campaign.raised.mul(platformFee)).div(FEE_DENOMINATOR);
            uint256 creatorAmount = campaign.raised.sub(platformFeeAmount);
            
            // Transfer funds
            userBalances[campaign.creator] = userBalances[campaign.creator].add(creatorAmount);
            userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
            
            // Reset raised amount to prevent double claiming
            uint256 claimedAmount = campaign.raised;
            campaign.raised = 0;
            
            emit CampaignFundsClaimed(campaignId, campaign.creator, claimedAmount);
            emit FeePaid(campaign.creator, platformFeeAmount, "Campaign Fee");
        } else {
            // Failed campaign - no funds for creator
            revert("Campaign did not reach its goal");
        }
    }
    
    // Refund contribution
    function refundCampaignContribution(uint256 campaignId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        CrowdfundingCampaign storage campaign = crowdfundingCampaigns[campaignId];
        CampaignContribution storage contribution = campaignContributions[campaignId][msg.sender];
        
        require(contribution.amount > 0, "No contribution to refund");
        require(!contribution.isRefunded, "Already refunded");
        
        // Check refund conditions
        bool canRefund = false;
        
        if (campaign.isClosed && !campaign.isSuccessful) {
            // Failed campaign - refund allowed
            canRefund = true;
        } else if (block.timestamp > campaign.deadline && campaign.raised < campaign.goal) {
            // Expired campaign that didn't reach goal - refund allowed
            canRefund = true;
        }
        
        require(canRefund, "Refund not allowed");
        
        // Process refund
        uint256 refundAmount = contribution.amount;
        contribution.isRefunded = true;
        
        // Transfer funds
        userBalances[msg.sender] = userBalances[msg.sender].add(refundAmount);
        
        emit CampaignContributionRefunded(campaignId, msg.sender, refundAmount);
    }
    
    // Get campaign details
    function getCampaignDetails(uint256 campaignId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address creator,
            uint256 goal,
            uint256 raised,
            uint256 creationTime,
            uint256 deadline,
            bool isClosed,
            bool isSuccessful,
            CampaignCategory category,
            string memory imageURI,
            uint256 backerCount,
            uint256 currentMilestone
        ) 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        CrowdfundingCampaign storage campaign = crowdfundingCampaigns[campaignId];
        
        return (
            campaign.name,
            campaign.description,
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.creationTime,
            campaign.deadline,
            campaign.isClosed,
            campaign.isSuccessful,
            campaign.category,
            campaign.imageURI,
            campaign.backerCount,
            campaign.currentMilestone
        );
    }
    
    // Get campaign milestones
    function getCampaignMilestones(uint256 campaignId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        return crowdfundingCampaigns[campaignId].milestones;
    }
    
    // Get campaign backers
    function getCampaignBackers(uint256 campaignId) 
        external 
        view 
        returns (address[] memory) 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        return campaignBackers[campaignId];
    }
    
    // Get contribution details
    function getContributionDetails(uint256 campaignId, address backer) 
        external 
        view 
        returns (
            uint256 amount,
            uint256 timestamp,
            bool isRefunded
        ) 
    {
        require(campaignId > 0 && campaignId <= _campaignIdCounter.current(), "Invalid campaign ID");
        
        CampaignContribution storage contribution = campaignContributions[campaignId][backer];
        
        return (
            contribution.amount,
            contribution.timestamp,
            contribution.isRefunded
        );
    }
    
    // Get user created campaigns
    function getUserCreatedCampaigns(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userCreatedCampaigns[user];
    }
    
    // Get user backed campaigns
    function getUserBackedCampaigns(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userBackedCampaigns[user];
    }
    
    // ==================== MULTI-SIG WALLET SYSTEM ====================
    
    // Structure for multi-sig wallet
    struct MultiSigWallet {
        uint256 id;
        string name;
        address[] owners;
        uint256 requiredConfirmations;
        uint256 creationTime;
        uint256 balance;
        uint256 transactionCount;
        bool isActive;
    }
    
    // Structure for multi-sig transaction
    struct MultiSigTransaction {
        uint256 id;
        uint256 walletId;
        address creator;
        address destination;
        uint256 value;
        bytes data;
        string description;
        uint256 creationTime;
        uint256 executionTime;
        bool isExecuted;
        bool isCancelled;
        mapping(address => bool) isConfirmed;
        uint256 confirmationCount;
    }
    
    // Mapping for multi-sig wallets and transactions
    mapping(uint256 => MultiSigWallet) public multiSigWallets;
    mapping(uint256 => mapping(uint256 => MultiSigTransaction)) public multiSigTransactions;
    mapping(address => uint256[]) public userMultiSigWallets;
    mapping(uint256 => uint256[]) public walletTransactions;
    mapping(address => mapping(uint256 => bool)) public isMultiSigWalletOwner;
    
    // Counter for multi-sig wallets
    Counters.Counter private _multiSigWalletIdCounter;
    
    // Events for multi-sig wallets
    event MultiSigWalletCreated(uint256 indexed walletId, address indexed creator, string name, uint256 requiredConfirmations);
    event MultiSigTransactionCreated(uint256 indexed walletId, uint256 indexed transactionId, address indexed creator, uint256 value);
    event MultiSigTransactionConfirmed(uint256 indexed walletId, uint256 indexed transactionId, address indexed confirmer);
    event MultiSigTransactionExecuted(uint256 indexed walletId, uint256 indexed transactionId, address indexed executor);
    event MultiSigTransactionCancelled(uint256 indexed walletId, uint256 indexed transactionId, address indexed canceller);
    event MultiSigWalletDeposit(uint256 indexed walletId, address indexed sender, uint256 value);
    event MultiSigWalletOwnerAdded(uint256 indexed walletId, address indexed newOwner);
    event MultiSigWalletOwnerRemoved(uint256 indexed walletId, address indexed owner);
    
    // Create multi-sig wallet
    function createMultiSigWallet(
        string memory name,
        address[] memory owners,
        uint256 requiredConfirmations
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(owners.length)
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(owners.length > 0, "No owners provided");
        require(requiredConfirmations > 0 && requiredConfirmations <= owners.length, "Invalid required confirmations");
        
        // Check owners are valid and unique
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            
            require(owner != address(0), "Invalid owner address");
            require(isRegistered[owner], "Owner not registered");
            
            for (uint256 j = i + 1; j < owners.length; j++) {
                require(owner != owners[j], "Duplicate owner");
            }
        }
        
        // Include creator if not already in owners
        bool creatorIncluded = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                creatorIncluded = true;
                break;
            }
        }
        
        // Increment wallet ID counter
        _multiSigWalletIdCounter.increment();
        uint256 newWalletId = _multiSigWalletIdCounter.current();
        
        // Create new wallet
        MultiSigWallet storage newWallet = multiSigWallets[newWalletId];
        newWallet.id = newWalletId;
        newWallet.name = name;
        newWallet.requiredConfirmations = requiredConfirmations;
        newWallet.creationTime = block.timestamp;
        newWallet.balance = 0;
        newWallet.transactionCount = 0;
        newWallet.isActive = true;
        
        // Add owners
        for (uint256 i = 0; i < owners.length; i++) {
            newWallet.owners.push(owners[i]);
            isMultiSigWalletOwner[owners[i]][newWalletId] = true;
            
            // Add to owner's wallets
            userMultiSigWallets[owners[i]].push(newWalletId);
        }
        
        // Add creator if not already included
        if (!creatorIncluded) {
            newWallet.owners.push(msg.sender);
            isMultiSigWalletOwner[msg.sender][newWalletId] = true;
            
            // Add to creator's wallets
            userMultiSigWallets[msg.sender].push(newWalletId);
        }
        
        // Pay creation fee
        uint256 creationFee = 0.01 ether;
        require(userBalances[msg.sender] >= creationFee, "Insufficient balance for creation fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(creationFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(creationFee);
        
        emit FeePaid(msg.sender, creationFee, "MultiSig Wallet Creation");
        emit MultiSigWalletCreated(newWalletId, msg.sender, name, requiredConfirmations);
        
        // Create notifications for owners
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] != msg.sender) {
                bytes32 entityId = keccak256(abi.encodePacked("multisig", newWalletId, "creation", owners[i]));
                createNotification(
                    owners[i],
                    "MULTISIG_WALLET_CREATED",
                    entityId,
                    string(abi.encodePacked("You have been added as an owner to the multisig wallet: ", name))
                );
            }
        }
    }
    
    // Deposit to multi-sig wallet
    function depositToMultiSigWallet(uint256 walletId) 
        external 
        payable
        whenNotPaused 
        nonReentrant 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        
        // Update wallet balance
        wallet.balance = wallet.balance.add(msg.value);
        
        // Create notification for wallet owners
        for (uint256 i = 0; i < wallet.owners.length; i++) {
            if (wallet.owners[i] != msg.sender) {
                bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "deposit", wallet.owners[i]));
                createNotification(
                    wallet.owners[i],
                    "MULTISIG_WALLET_DEPOSIT",
                    entityId,
                    string(abi.encodePacked("Multisig wallet received a deposit of ", msg.value.toString(), " wei"))
                );
            }
        }
        
        emit MultiSigWalletDeposit(walletId, msg.sender, msg.value);
    }
    
    // Create multi-sig transaction
    function createMultiSigTransaction(
        uint256 walletId,
        address destination,
        uint256 value,
        bytes memory data,
        string memory description
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        require(destination != address(0), "Invalid destination address");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        require(wallet.balance >= value, "Insufficient wallet balance");
        
        // Increment transaction counter
        wallet.transactionCount += 1;
        uint256 newTransactionId = wallet.transactionCount;
        
        // Create new transaction
        MultiSigTransaction storage newTransaction = multiSigTransactions[walletId][newTransactionId];
        newTransaction.id = newTransactionId;
        newTransaction.walletId = walletId;
        newTransaction.creator = msg.sender;
        newTransaction.destination = destination;
        newTransaction.value = value;
        newTransaction.data = data;
        newTransaction.description = description;
        newTransaction.creationTime = block.timestamp;
        newTransaction.isExecuted = false;
        newTransaction.isCancelled = false;
        
        // Auto-confirm by creator
        newTransaction.isConfirmed[msg.sender] = true;
        newTransaction.confirmationCount = 1;
        
        // Add to wallet transactions
        walletTransactions[walletId].push(newTransactionId);
        
        // SPDX-License-Identifier: MIT
// PART 10/12 - MonadEcosystemHubV1
// Advanced Payments & Financial Functions
// Continues from PART 9/12

// CONTINUED FROM PART 9/12 (continued)

        // Create notification for other wallet owners
        for (uint256 i = 0; i < wallet.owners.length; i++) {
            if (wallet.owners[i] != msg.sender) {
                bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "transaction", newTransactionId, wallet.owners[i]));
                createNotification(
                    wallet.owners[i],
                    "MULTISIG_TRANSACTION_CREATED",
                    entityId,
                    string(abi.encodePacked("New multisig transaction created with ID: ", uint256(newTransactionId).toString()))
                );
            }
        }
        
        emit MultiSigTransactionCreated(walletId, newTransactionId, msg.sender, value);
    }
    
    // Confirm multi-sig transaction
    function confirmMultiSigTransaction(uint256 walletId, uint256 transactionId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        
        MultiSigTransaction storage transaction = multiSigTransactions[walletId][transactionId];
        require(transaction.id > 0, "Transaction does not exist");
        require(!transaction.isExecuted, "Transaction already executed");
        require(!transaction.isCancelled, "Transaction cancelled");
        require(!transaction.isConfirmed[msg.sender], "Transaction already confirmed");
        
        // Confirm transaction
        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmationCount += 1;
        
        // Create notification for transaction creator
        bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "confirmation", transactionId, transaction.creator));
        createNotification(
            transaction.creator,
            "MULTISIG_TRANSACTION_CONFIRMED",
            entityId,
            string(abi.encodePacked("Your multisig transaction with ID: ", uint256(transactionId).toString(), " has been confirmed by ", 
                string(abi.encodePacked(uint256(uint160(msg.sender)).toHexString()))
            ))
        );
        
        emit MultiSigTransactionConfirmed(walletId, transactionId, msg.sender);
    }
    
    // Execute multi-sig transaction
    function executeMultiSigTransaction(uint256 walletId, uint256 transactionId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        
        MultiSigTransaction storage transaction = multiSigTransactions[walletId][transactionId];
        require(transaction.id > 0, "Transaction does not exist");
        require(!transaction.isExecuted, "Transaction already executed");
        require(!transaction.isCancelled, "Transaction cancelled");
        require(transaction.confirmationCount >= wallet.requiredConfirmations, "Not enough confirmations");
        require(wallet.balance >= transaction.value, "Insufficient wallet balance");
        
        // Mark as executed
        transaction.isExecuted = true;
        transaction.executionTime = block.timestamp;
        
        // Update wallet balance
        wallet.balance = wallet.balance.sub(transaction.value);
        
        // Execute transaction
        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        require(success, "Transaction execution failed");
        
        // Create notification for wallet owners
        for (uint256 i = 0; i < wallet.owners.length; i++) {
            if (wallet.owners[i] != msg.sender) {
                bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "execution", transactionId, wallet.owners[i]));
                createNotification(
                    wallet.owners[i],
                    "MULTISIG_TRANSACTION_EXECUTED",
                    entityId,
                    string(abi.encodePacked("Multisig transaction with ID: ", uint256(transactionId).toString(), " has been executed"))
                );
            }
        }
        
        emit MultiSigTransactionExecuted(walletId, transactionId, msg.sender);
    }
    
    // Cancel multi-sig transaction
    function cancelMultiSigTransaction(uint256 walletId, uint256 transactionId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        
        MultiSigTransaction storage transaction = multiSigTransactions[walletId][transactionId];
        require(transaction.id > 0, "Transaction does not exist");
        require(!transaction.isExecuted, "Transaction already executed");
        require(!transaction.isCancelled, "Transaction already cancelled");
        
        // Only creator or wallet owner with special permission can cancel
        require(transaction.creator == msg.sender || msg.sender == owner(), "Not authorized to cancel");
        
        // Mark as cancelled
        transaction.isCancelled = true;
        
        // Create notification for wallet owners
        for (uint256 i = 0; i < wallet.owners.length; i++) {
            if (wallet.owners[i] != msg.sender) {
                bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "cancellation", transactionId, wallet.owners[i]));
                createNotification(
                    wallet.owners[i],
                    "MULTISIG_TRANSACTION_CANCELLED",
                    entityId,
                    string(abi.encodePacked("Multisig transaction with ID: ", uint256(transactionId).toString(), " has been cancelled"))
                );
            }
        }
        
        emit MultiSigTransactionCancelled(walletId, transactionId, msg.sender);
    }
    
    // Add owner to multi-sig wallet
    function addMultiSigWalletOwner(uint256 walletId, address newOwner) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        require(newOwner != address(0), "Invalid owner address");
        require(isRegistered[newOwner], "Owner not registered");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        require(!isMultiSigWalletOwner[newOwner][walletId], "Already an owner");
        
        // Add new owner
        wallet.owners.push(newOwner);
        isMultiSigWalletOwner[newOwner][walletId] = true;
        
        // Add to new owner's wallets
        userMultiSigWallets[newOwner].push(walletId);
        
        // Create notification for new owner
        bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "newowner", newOwner));
        createNotification(
            newOwner,
            "MULTISIG_WALLET_OWNER_ADDED",
            entityId,
            string(abi.encodePacked("You have been added as an owner to the multisig wallet: ", wallet.name))
        );
        
        emit MultiSigWalletOwnerAdded(walletId, newOwner);
    }
    
    // Remove owner from multi-sig wallet
    function removeMultiSigWalletOwner(uint256 walletId, address owner) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        require(isMultiSigWalletOwner[owner][walletId], "Not an owner");
        require(wallet.owners.length > wallet.requiredConfirmations, "Cannot remove owner below required confirmations");
        
        // Remove owner
        for (uint256 i = 0; i < wallet.owners.length; i++) {
            if (wallet.owners[i] == owner) {
                // Swap with last element and pop
                wallet.owners[i] = wallet.owners[wallet.owners.length - 1];
                wallet.owners.pop();
                break;
            }
        }
        
        isMultiSigWalletOwner[owner][walletId] = false;
        
        // Remove from owner's wallets
        for (uint256 i = 0; i < userMultiSigWallets[owner].length; i++) {
            if (userMultiSigWallets[owner][i] == walletId) {
                // Swap with last element and pop
                userMultiSigWallets[owner][i] = userMultiSigWallets[owner][userMultiSigWallets[owner].length - 1];
                userMultiSigWallets[owner].pop();
                break;
            }
        }
        
        // Create notification for removed owner
        bytes32 entityId = keccak256(abi.encodePacked("multisig", walletId, "removeowner", owner));
        createNotification(
            owner,
            "MULTISIG_WALLET_OWNER_REMOVED",
            entityId,
            string(abi.encodePacked("You have been removed as an owner from the multisig wallet: ", wallet.name))
        );
        
        emit MultiSigWalletOwnerRemoved(walletId, owner);
    }
    
    // Change required confirmations
    function changeRequiredConfirmations(uint256 walletId, uint256 newRequiredConfirmations) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        require(wallet.isActive, "Wallet not active");
        require(isMultiSigWalletOwner[msg.sender][walletId], "Not a wallet owner");
        require(newRequiredConfirmations > 0, "Required confirmations must be greater than 0");
        require(newRequiredConfirmations <= wallet.owners.length, "Required confirmations cannot exceed owner count");
        
        // Update required confirmations
        wallet.requiredConfirmations = newRequiredConfirmations;
    }
    
    // Get multi-sig wallet details
    function getMultiSigWalletDetails(uint256 walletId) 
        external 
        view 
        returns (
            string memory name,
            address[] memory owners,
            uint256 requiredConfirmations,
            uint256 balance,
            uint256 transactionCount,
            bool isActive
        ) 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigWallet storage wallet = multiSigWallets[walletId];
        
        return (
            wallet.name,
            wallet.owners,
            wallet.requiredConfirmations,
            wallet.balance,
            wallet.transactionCount,
            wallet.isActive
        );
    }
    
    // Get multi-sig transaction details
    function getMultiSigTransactionDetails(uint256 walletId, uint256 transactionId) 
        external 
        view 
        returns (
            address creator,
            address destination,
            uint256 value,
            string memory description,
            uint256 creationTime,
            uint256 executionTime,
            bool isExecuted,
            bool isCancelled,
            uint256 confirmationCount
        ) 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigTransaction storage transaction = multiSigTransactions[walletId][transactionId];
        require(transaction.id > 0, "Transaction does not exist");
        
        return (
            transaction.creator,
            transaction.destination,
            transaction.value,
            transaction.description,
            transaction.creationTime,
            transaction.executionTime,
            transaction.isExecuted,
            transaction.isCancelled,
            transaction.confirmationCount
        );
    }
    
    // Check if owner confirmed transaction
    function isTransactionConfirmedByOwner(uint256 walletId, uint256 transactionId, address owner) 
        external 
        view 
        returns (bool) 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        MultiSigTransaction storage transaction = multiSigTransactions[walletId][transactionId];
        require(transaction.id > 0, "Transaction does not exist");
        
        return transaction.isConfirmed[owner];
    }
    
    // Get wallet transactions
    function getWalletTransactions(uint256 walletId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        require(walletId > 0 && walletId <= _multiSigWalletIdCounter.current(), "Invalid wallet ID");
        
        return walletTransactions[walletId];
    }
    
    // Get user multi-sig wallets
    function getUserMultiSigWallets(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userMultiSigWallets[user];
    }
    
    // ==================== REWARD SYSTEM ====================
    
    // Structure for reward
    struct Reward {
        uint256 id;
        string name;
        string description;
        uint256 points;
        address creator;
        uint256 creationTime;
        bool isActive;
        uint256 claimCount;
        uint256 totalPointsAwarded;
    }
    
    // Structure for reward claim
    struct RewardClaim {
        uint256 rewardId;
        address claimer;
        uint256 claimTime;
        uint256 pointsAwarded;
    }
    
    // Mapping for rewards
    mapping(uint256 => Reward) public rewards;
    mapping(uint256 => mapping(address => RewardClaim)) public rewardClaims;
    mapping(address => uint256[]) public userClaimedRewards;
    mapping(address => uint256) public userRewardPoints;
    
    // Counter for rewards
    Counters.Counter private _rewardIdCounter;
    
    // Events for rewards
    event RewardCreated(uint256 indexed rewardId, address indexed creator, string name, uint256 points);
    event RewardClaimed(uint256 indexed rewardId, address indexed claimer, uint256 pointsAwarded);
    
    // Create reward
    function createReward(
        string memory name,
        string memory description,
        uint256 points
    ) 
        external 
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(points > 0, "Points must be greater than 0");
        
        // Increment reward ID counter
        _rewardIdCounter.increment();
        uint256 newRewardId = _rewardIdCounter.current();
        
        // Create new reward
        Reward storage newReward = rewards[newRewardId];
        newReward.id = newRewardId;
        newReward.name = name;
        newReward.description = description;
        newReward.points = points;
        newReward.creator = msg.sender;
        newReward.creationTime = block.timestamp;
        newReward.isActive = true;
        
        emit RewardCreated(newRewardId, msg.sender, name, points);
    }
    
    // Claim reward
    function claimReward(uint256 rewardId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        
        Reward storage reward = rewards[rewardId];
        require(reward.isActive, "Reward not active");
        
        // Check if already claimed
        require(rewardClaims[rewardId][msg.sender].claimTime == 0, "Reward already claimed");
        
        // Create reward claim
        RewardClaim storage claim = rewardClaims[rewardId][msg.sender];
        claim.rewardId = rewardId;
        claim.claimer = msg.sender;
        claim.claimTime = block.timestamp;
        claim.pointsAwarded = reward.points;
        
        // Update reward stats
        reward.claimCount += 1;
        reward.totalPointsAwarded += reward.points;
        
        // Update user stats
        userClaimedRewards[msg.sender].push(rewardId);
        userRewardPoints[msg.sender] += reward.points;
        
        // Update user reputation
        userReputation[msg.sender] += reward.points;
        
        emit RewardClaimed(rewardId, msg.sender, reward.points);
    }
    
    // Award reward to user
    function awardReward(uint256 rewardId, address user) 
        external 
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");
        
        Reward storage reward = rewards[rewardId];
        require(reward.isActive, "Reward not active");
        
        // Check if already claimed
        require(rewardClaims[rewardId][user].claimTime == 0, "Reward already claimed");
        
        // Create reward claim
        RewardClaim storage claim = rewardClaims[rewardId][user];
        claim.rewardId = rewardId;
        claim.claimer = user;
        claim.claimTime = block.timestamp;
        claim.pointsAwarded = reward.points;
        
        // Update reward stats
        reward.claimCount += 1;
        reward.totalPointsAwarded += reward.points;
        
        // Update user stats
        userClaimedRewards[user].push(rewardId);
        userRewardPoints[user] += reward.points;
        
        // Update user reputation
        userReputation[user] += reward.points;
        
        // Create notification for user
        bytes32 entityId = keccak256(abi.encodePacked("reward", rewardId, user));
        createNotification(
            user,
            "REWARD_AWARDED",
            entityId,
            string(abi.encodePacked("You have been awarded the reward: ", reward.name, " (", uint256(reward.points).toString(), " points)"))
        );
        
        emit RewardClaimed(rewardId, user, reward.points);
    }
    
    // Activate/deactivate reward
    function setRewardActive(uint256 rewardId, bool isActive) 
        external 
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        
        rewards[rewardId].isActive = isActive;
    }
    
    // Get reward details
    function getRewardDetails(uint256 rewardId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            uint256 points,
            address creator,
            uint256 creationTime,
            bool isActive,
            uint256 claimCount,
            uint256 totalPointsAwarded
        ) 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        
        Reward storage reward = rewards[rewardId];
        
        return (
            reward.name,
            reward.description,
            reward.points,
            reward.creator,
            reward.creationTime,
            reward.isActive,
            reward.claimCount,
            reward.totalPointsAwarded
        );
    }
    
    // Check if user claimed reward
    function hasClaimedReward(uint256 rewardId, address user) 
        external 
        view 
        returns (bool) 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        
        return rewardClaims[rewardId][user].claimTime > 0;
    }
    
    // Get user claimed rewards
    function getUserClaimedRewards(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userClaimedRewards[user];
    }
    
    // Get user reward points
    function getUserRewardPoints(address user) 
        external 
        view 
        returns (uint256) 
    {
        return userRewardPoints[user];
    }
    
    // Get all rewards
    function getAllRewards() 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = _rewardIdCounter.current();
        uint256[] memory rewardIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            rewardIds[i] = i + 1;
        }
        
        return rewardIds;
    }
    
    // Get active rewards
    function getActiveRewards() 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = _rewardIdCounter.current();
        uint256 activeCount = 0;
        
        // Count active rewards
        for (uint256 i = 1; i <= count; i++) {
            if (rewards[i].isActive) {
                activeCount++;
            }
        }
        
        // Create result array
        uint256[] memory activeRewardIds = new uint256[](activeCount);
        uint256 index = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= count; i++) {
            if (rewards[i].isActive) {
                activeRewardIds[index] = i;
                index++;
            }
        }
        
        return activeRewardIds;
    }
    
    // Get reward claim details
    function getRewardClaimDetails(uint256 rewardId, address user) 
        external 
        view 
        returns (
            uint256 claimTime,
            uint256 pointsAwarded
        ) 
    {
        require(rewardId > 0 && rewardId <= _rewardIdCounter.current(), "Invalid reward ID");
        
        RewardClaim storage claim = rewardClaims[rewardId][user];
        
        return (
            claim.claimTime,
            claim.pointsAwarded
        );
    }
    
    // Generate reward for user (internal use for achievements)
    function _generateRewardForUser(string memory name, string memory description, uint256 points, address user) 
        internal 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(points > 0, "Points must be greater than 0");
        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");
        
        // Increment reward ID counter
        _rewardIdCounter.increment();
        uint256 newRewardId = _rewardIdCounter.current();
        
        // Create new reward
        Reward storage newReward = rewards[newRewardId];
        newReward.id = newRewardId;
        newReward.name = name;
        newReward.description = description;
        newReward.points = points;
        newReward.creator = address(this);
        newReward.creationTime = block.timestamp;
        newReward.isActive = true;
        
        // Create reward claim
        RewardClaim storage claim = rewardClaims[newRewardId][user];
        claim.rewardId = newRewardId;
        claim.claimer = user;
        claim.claimTime = block.timestamp;
        claim.pointsAwarded = points;
        
        // Update reward stats
        newReward.claimCount = 1;
        newReward.totalPointsAwarded = points;
        
        // Update user stats
        userClaimedRewards[user].push(newRewardId);
        userRewardPoints[user] += points;
        
        // Update user reputation
        userReputation[user] += points;
        
        // Create notification for user
        bytes32 entityId = keccak256(abi.encodePacked("reward", newRewardId, user));
        createNotification(
            user,
            "REWARD_AWARDED",
            entityId,
            string(abi.encodePacked("You have been awarded the reward: ", name, " (", uint256(points).toString(), " points)"))
        );
        
        emit RewardCreated(newRewardId, address(this), name, points);
        emit RewardClaimed(newRewardId, user, points);
    }
    
// END OF PART 10/12 - CONTINUE TO PART 11/12
// SPDX-License-Identifier: MIT
// PART 11/12 - MonadEcosystemHubV1
// Advanced Marketplace & Trading Functions
// Continues from PART 10/12

// CONTINUED FROM PART 10/12

    // ==================== MARKETPLACE SYSTEM ====================
    
    // Structure for marketplace item
    struct MarketplaceItem {
        uint256 id;
        string name;
        string description;
        address seller;
        uint256 price;
        ItemType itemType;
        ItemStatus status;
        uint256 creationTime;
        uint256 lastUpdateTime;
        uint256 quantity;
        string mediaURI;
        bytes32 contentHash;
        ItemAttributes attributes;
    }
    
    // Structure for item attributes
    struct ItemAttributes {
        string[] tags;
        uint256[] values;
        string[] propertyNames;
        string[] propertyValues;
        bool isVerified;
        bool isTransferable;
        bool isConsumable;
        bool isStackable;
    }
    
    // Enum for item type
    enum ItemType { PHYSICAL, DIGITAL, VIRTUAL, SERVICE, SUBSCRIPTION, NFT }
    
    // Enum for item status
    enum ItemStatus { LISTED, SOLD, REMOVED, RESERVED, EXPIRED }
    
    // Structure for marketplace order
    struct MarketplaceOrder {
        uint256 id;
        uint256 itemId;
        address buyer;
        address seller;
        uint256 price;
        uint256 quantity;
        uint256 orderTime;
        OrderStatus status;
        string shippingDetails;
        string notes;
        uint256 completionTime;
        bool isRated;
        uint8 rating;
    }
    
    // Enum for order status
    enum OrderStatus { CREATED, PAID, PROCESSING, SHIPPED, DELIVERED, COMPLETED, CANCELLED, REFUNDED }
    
    // Mapping for marketplace items and orders
    mapping(uint256 => MarketplaceItem) public marketplaceItems;
    mapping(uint256 => MarketplaceOrder) public marketplaceOrders;
    mapping(address => uint256[]) public sellerItems;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256[]) public sellerOrders;
    mapping(ItemType => uint256[]) public itemsByType;
    mapping(string => uint256[]) public itemsByTag;
    
    // Counter for marketplace items and orders
    Counters.Counter private _itemIdCounter;
    Counters.Counter private _orderIdCounter;
    
    // Events for marketplace
    event MarketplaceItemCreated(uint256 indexed itemId, address indexed seller, string name, uint256 price);
    event MarketplaceItemUpdated(uint256 indexed itemId, address indexed seller, uint256 price);
    event MarketplaceItemRemoved(uint256 indexed itemId, address indexed seller);
    event MarketplaceOrderCreated(uint256 indexed orderId, uint256 indexed itemId, address indexed buyer, uint256 price);
    event MarketplaceOrderStatusChanged(uint256 indexed orderId, OrderStatus status);
    event MarketplaceOrderCompleted(uint256 indexed orderId, address indexed buyer, address indexed seller);
    
    // Create marketplace item
    function createMarketplaceItem(
        string memory name,
        string memory description,
        uint256 price,
        ItemType itemType,
        uint256 quantity,
        string memory mediaURI,
        bytes32 contentHash,
        ItemAttributes memory attributes
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(attributes.tags.length)
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");
        
        // Increment item ID counter
        _itemIdCounter.increment();
        uint256 newItemId = _itemIdCounter.current();
        
        // Create new item
        MarketplaceItem storage newItem = marketplaceItems[newItemId];
        newItem.id = newItemId;
        newItem.name = name;
        newItem.description = description;
        newItem.seller = msg.sender;
        newItem.price = price;
        newItem.itemType = itemType;
        newItem.status = ItemStatus.LISTED;
        newItem.creationTime = block.timestamp;
        newItem.lastUpdateTime = block.timestamp;
        newItem.quantity = quantity;
        newItem.mediaURI = mediaURI;
        newItem.contentHash = contentHash;
        
        // Set attributes
        require(attributes.propertyNames.length == attributes.propertyValues.length, "Property arrays length mismatch");
        
        newItem.attributes = attributes;
        
        // Add to seller's items
        sellerItems[msg.sender].push(newItemId);
        
        // Add to item type mapping
        itemsByType[itemType].push(newItemId);
        
        // Add to tags mapping
        for (uint256 i = 0; i < attributes.tags.length; i++) {
            itemsByTag[attributes.tags[i]].push(newItemId);
        }
        
        // Pay listing fee
        uint256 listingFee = 0.01 ether;
        require(userBalances[msg.sender] >= listingFee, "Insufficient balance for listing fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(listingFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(listingFee);
        
        emit FeePaid(msg.sender, listingFee, "Marketplace Listing");
        emit MarketplaceItemCreated(newItemId, msg.sender, name, price);
    }
    
    // Update marketplace item
    function updateMarketplaceItem(
        uint256 itemId,
        string memory description,
        uint256 price,
        uint256 quantity,
        string memory mediaURI
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.seller == msg.sender, "Not the item seller");
        require(item.status == ItemStatus.LISTED, "Item not listed");
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");
        
        // Update item
        item.description = description;
        item.price = price;
        item.quantity = quantity;
        item.mediaURI = mediaURI;
        item.lastUpdateTime = block.timestamp;
        
        emit MarketplaceItemUpdated(itemId, msg.sender, price);
    }
    
    // Update item attributes
    function updateItemAttributes(
        uint256 itemId,
        ItemAttributes memory attributes
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(attributes.tags.length)
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.seller == msg.sender, "Not the item seller");
        require(item.status == ItemStatus.LISTED, "Item not listed");
        require(attributes.propertyNames.length == attributes.propertyValues.length, "Property arrays length mismatch");
        
        // Remove old tags from mapping
        for (uint256 i = 0; i < item.attributes.tags.length; i++) {
            string memory oldTag = item.attributes.tags[i];
            uint256[] storage items = itemsByTag[oldTag];
            
            for (uint256 j = 0; j < items.length; j++) {
                if (items[j] == itemId) {
                    // Replace with last element and pop
                    items[j] = items[items.length - 1];
                    items.pop();
                    break;
                }
            }
        }
        
        // Update attributes
        item.attributes = attributes;
        item.lastUpdateTime = block.timestamp;
        
        // Add to tags mapping
        for (uint256 i = 0; i < attributes.tags.length; i++) {
            itemsByTag[attributes.tags[i]].push(itemId);
        }
        
        emit MarketplaceItemUpdated(itemId, msg.sender, item.price);
    }
    
    // Remove marketplace item
    function removeMarketplaceItem(uint256 itemId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.seller == msg.sender || msg.sender == owner(), "Not authorized");
        require(item.status == ItemStatus.LISTED, "Item not listed");
        
        // Update item status
        item.status = ItemStatus.REMOVED;
        item.lastUpdateTime = block.timestamp;
        
        emit MarketplaceItemRemoved(itemId, msg.sender);
    }
    
    // Verify item (owner only)
    function verifyMarketplaceItem(uint256 itemId) 
        external 
        whenNotPaused 
        onlyOwner 
        nonReentrant 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.status == ItemStatus.LISTED, "Item not listed");
        
        // Update verified status
        item.attributes.isVerified = true;
        item.lastUpdateTime = block.timestamp;
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", itemId, "verified"));
        createNotification(
            item.seller,
            "MARKETPLACE_ITEM_VERIFIED",
            entityId,
            string(abi.encodePacked("Your marketplace item has been verified: ", item.name))
        );
        
        emit MarketplaceItemUpdated(itemId, item.seller, item.price);
    }
    
    // Create marketplace order
    function createMarketplaceOrder(
        uint256 itemId,
        uint256 quantity,
        string memory shippingDetails,
        string memory notes
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        require(quantity > 0, "Quantity must be greater than 0");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.status == ItemStatus.LISTED, "Item not listed");
        require(item.quantity >= quantity, "Insufficient quantity available");
        require(item.seller != msg.sender, "Cannot purchase own item");
        
        // Calculate total price
        uint256 totalPrice = item.price.mul(quantity);
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Increment order ID counter
        _orderIdCounter.increment();
        uint256 newOrderId = _orderIdCounter.current();
        
        // Create new order
        MarketplaceOrder storage newOrder = marketplaceOrders[newOrderId];
        newOrder.id = newOrderId;
        newOrder.itemId = itemId;
        newOrder.buyer = msg.sender;
        newOrder.seller = item.seller;
        newOrder.price = totalPrice;
        newOrder.quantity = quantity;
        newOrder.orderTime = block.timestamp;
        newOrder.status = OrderStatus.PAID;
        newOrder.shippingDetails = shippingDetails;
        newOrder.notes = notes;
        
        // Update item quantity
        item.quantity = item.quantity.sub(quantity);
        item.lastUpdateTime = block.timestamp;
        
        // If quantity becomes zero, mark as sold
        if (item.quantity == 0) {
            item.status = ItemStatus.SOLD;
        }
        
        // Add to buyer's and seller's orders
        buyerOrders[msg.sender].push(newOrderId);
        sellerOrders[item.seller].push(newOrderId);
        
        // Calculate platform fee
        uint256 platformFeeAmount = (totalPrice.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 sellerAmount = totalPrice.sub(platformFeeAmount);
        
        // Transfer funds
        userBalances[item.seller] = userBalances[item.seller].add(sellerAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(totalPrice));
        }
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", itemId, "order", newOrderId));
        createNotification(
            item.seller,
            "MARKETPLACE_ORDER_RECEIVED",
            entityId,
            string(abi.encodePacked("You have received a new order for: ", item.name))
        );
        
        emit FeePaid(msg.sender, platformFeeAmount, "Marketplace Fee");
        emit MarketplaceOrderCreated(newOrderId, itemId, msg.sender, totalPrice);
    }
    
    // Update order status
    function updateOrderStatus(uint256 orderId, OrderStatus newStatus) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(orderId > 0 && orderId <= _orderIdCounter.current(), "Invalid order ID");
        
        MarketplaceOrder storage order = marketplaceOrders[orderId];
        require(order.seller == msg.sender || msg.sender == owner(), "Not authorized");
        
        // Validate status transitions
        if (newStatus == OrderStatus.PROCESSING) {
            require(order.status == OrderStatus.PAID, "Invalid status transition");
        } else if (newStatus == OrderStatus.SHIPPED) {
            require(order.status == OrderStatus.PROCESSING, "Invalid status transition");
        } else if (newStatus == OrderStatus.DELIVERED) {
            require(order.status == OrderStatus.SHIPPED, "Invalid status transition");
        } else if (newStatus == OrderStatus.COMPLETED) {
            require(
                order.status == OrderStatus.DELIVERED || 
                (order.status == OrderStatus.PAID && 
                 marketplaceItems[order.itemId].itemType != ItemType.PHYSICAL),
                "Invalid status transition"
            );
            
            // Set completion time
            order.completionTime = block.timestamp;
        } else if (newStatus == OrderStatus.CANCELLED) {
            require(
                order.status == OrderStatus.PAID || 
                order.status == OrderStatus.PROCESSING,
                "Invalid status transition"
            );
            
            // Refund buyer
            userBalances[order.buyer] = userBalances[order.buyer].add(order.price);
            
            // Deduct from seller
            userBalances[order.seller] = userBalances[order.seller].sub(order.price);
            
            // Restore item quantity
            MarketplaceItem storage item = marketplaceItems[order.itemId];
            item.quantity = item.quantity.add(order.quantity);
            
            // If item was sold out, set it back to listed
            if (item.status == ItemStatus.SOLD) {
                item.status = ItemStatus.LISTED;
            }
        } else if (newStatus == OrderStatus.REFUNDED) {
            require(
                order.status == OrderStatus.PAID || 
                order.status == OrderStatus.PROCESSING || 
                order.status == OrderStatus.SHIPPED,
                "Invalid status transition"
            );
            
            // Refund buyer
            userBalances[order.buyer] = userBalances[order.buyer].add(order.price);
            
            // Deduct from seller
            userBalances[order.seller] = userBalances[order.seller].sub(order.price);
            
            // Restore item quantity only if item not received
            if (order.status != OrderStatus.DELIVERED) {
                MarketplaceItem storage item = marketplaceItems[order.itemId];
                item.quantity = item.quantity.add(order.quantity);
                
                // If item was sold out, set it back to listed
                if (item.status == ItemStatus.SOLD) {
                    item.status = ItemStatus.LISTED;
                }
            }
        }
        
        // Update order status
        order.status = newStatus;
        
        // Create notification for buyer
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", "order", orderId, "status"));
        createNotification(
            order.buyer,
            "ORDER_STATUS_UPDATED",
            entityId,
            string(abi.encodePacked("Your order status has been updated to: ", orderStatusToString(newStatus)))
        );
        
        emit MarketplaceOrderStatusChanged(orderId, newStatus);
        
        // When completing order, also emit completion event
        if (newStatus == OrderStatus.COMPLETED) {
            emit MarketplaceOrderCompleted(orderId, order.buyer, order.seller);
        }
    }
    
    // Helper function to convert order status to string
    function orderStatusToString(OrderStatus status) 
        internal 
        pure 
        returns (string memory) 
    {
        if (status == OrderStatus.CREATED) return "Created";
        if (status == OrderStatus.PAID) return "Paid";
        if (status == OrderStatus.PROCESSING) return "Processing";
        if (status == OrderStatus.SHIPPED) return "Shipped";
        if (status == OrderStatus.DELIVERED) return "Delivered";
        if (status == OrderStatus.COMPLETED) return "Completed";
        if (status == OrderStatus.CANCELLED) return "Cancelled";
        if (status == OrderStatus.REFUNDED) return "Refunded";
        return "Unknown";
    }
    
    // Rate order
    function rateOrder(uint256 orderId, uint8 rating) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(orderId > 0 && orderId <= _orderIdCounter.current(), "Invalid order ID");
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        
        MarketplaceOrder storage order = marketplaceOrders[orderId];
        require(order.buyer == msg.sender, "Not the order buyer");
        require(order.status == OrderStatus.COMPLETED, "Order not completed");
        require(!order.isRated, "Order already rated");
        
        // Update order rating
        order.isRated = true;
        order.rating = rating;
        
        // Update seller reputation based on rating
        if (rating >= 4) {
            userReputation[order.seller] = userReputation[order.seller].add(5);
        } else if (rating == 3) {
            userReputation[order.seller] = userReputation[order.seller].add(2);
        } else if (rating <= 2) {
            if (userReputation[order.seller] >= 5) {
                userReputation[order.seller] = userReputation[order.seller].sub(5);
            }
        }
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", "order", orderId, "rating"));
        createNotification(
            order.seller,
            "ORDER_RATED",
            entityId,
            string(abi.encodePacked("Your order has been rated with ", uint256(rating).toString(), " stars"))
        );
    }
    
    // Confirm delivery
    function confirmDelivery(uint256 orderId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(orderId > 0 && orderId <= _orderIdCounter.current(), "Invalid order ID");
        
        MarketplaceOrder storage order = marketplaceOrders[orderId];
        require(order.buyer == msg.sender, "Not the order buyer");
        require(
            order.status == OrderStatus.SHIPPED || 
            order.status == OrderStatus.PAID && 
            marketplaceItems[order.itemId].itemType != ItemType.PHYSICAL,
            "Invalid order status"
        );
        
        // Update order status
        order.status = OrderStatus.DELIVERED;
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", "order", orderId, "delivery"));
        createNotification(
            order.seller,
            "ORDER_DELIVERED",
            entityId,
            string(abi.encodePacked("Buyer confirmed delivery of your order"))
        );
        
        emit MarketplaceOrderStatusChanged(orderId, OrderStatus.DELIVERED);
    }
    
    // Complete order
    function completeOrder(uint256 orderId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(orderId > 0 && orderId <= _orderIdCounter.current(), "Invalid order ID");
        
        MarketplaceOrder storage order = marketplaceOrders[orderId];
        
        // Either buyer or seller can complete delivery
        if (msg.sender == order.buyer) {
            require(order.status == OrderStatus.DELIVERED, "Order not delivered");
        } else if (msg.sender == order.seller) {
            require(
                order.status == OrderStatus.DELIVERED || 
                (order.status == OrderStatus.PAID && 
                 marketplaceItems[order.itemId].itemType != ItemType.PHYSICAL),
                "Invalid order status"
            );
        } else {
            revert("Not authorized");
        }
        
        // Update order status
        order.status = OrderStatus.COMPLETED;
        order.completionTime = block.timestamp;
        
        // Create notification for the other party
        address notificationRecipient = (msg.sender == order.buyer) ? order.seller : order.buyer;
        bytes32 entityId = keccak256(abi.encodePacked("marketplace", "order", orderId, "completion"));
        createNotification(
            notificationRecipient,
            "ORDER_COMPLETED",
            entityId,
            string(abi.encodePacked("Your order has been marked as completed"))
        );
        
        emit MarketplaceOrderStatusChanged(orderId, OrderStatus.COMPLETED);
        emit MarketplaceOrderCompleted(orderId, order.buyer, order.seller);
    }
    
    // Get marketplace item details
    function getMarketplaceItemDetails(uint256 itemId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address seller,
            uint256 price,
            ItemType itemType,
            ItemStatus status,
            uint256 quantity,
            string memory mediaURI,
            bool isVerified
        ) 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        
        return (
            item.name,
            item.description,
            item.seller,
            item.price,
            item.itemType,
            item.status,
            item.quantity,
            item.mediaURI,
            item.attributes.isVerified
        );
    }
    
    // Get item attributes
    function getItemAttributes(uint256 itemId) 
        external 
        view 
        returns (ItemAttributes memory) 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        
        return marketplaceItems[itemId].attributes;
    }
    
    // Get marketplace order details
    function getMarketplaceOrderDetails(uint256 orderId) 
        external 
        view 
        returns (
            uint256 itemId,
            address buyer,
            address seller,
            uint256 price,
            uint256 quantity,
            uint256 orderTime,
            OrderStatus status,
            string memory shippingDetails,
            string memory notes,
            uint256 completionTime,
            bool isRated,
            uint8 rating
        ) 
    {
        require(orderId > 0 && orderId <= _orderIdCounter.current(), "Invalid order ID");
        
        MarketplaceOrder storage order = marketplaceOrders[orderId];
        
        // Only buyer, seller, or owner can view shipping details
        string memory viewableShippingDetails = "";
        if (msg.sender == order.buyer || msg.sender == order.seller || msg.sender == owner()) {
            viewableShippingDetails = order.shippingDetails;
        }
        
        return (
            order.itemId,
            order.buyer,
            order.seller,
            order.price,
            order.quantity,
            order.orderTime,
            order.status,
            viewableShippingDetails,
            order.notes,
            order.completionTime,
            order.isRated,
            order.rating
        );
    }
    
    // Get seller's items
    function getSellerItems(address seller) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return sellerItems[seller];
    }
    
    // Get buyer's orders
    function getBuyerOrders(address buyer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return buyerOrders[buyer];
    }
    
    // Get seller's orders
    function getSellerOrders(address seller) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return sellerOrders[seller];
    }
    
    // Get items by type
    function getItemsByType(ItemType itemType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return itemsByType[itemType];
    }
    
    // Get items by tag
    function getItemsByTag(string memory tag) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return itemsByTag[tag];
    }
    
    // Get active marketplace items (paginated)
    function getActiveMarketplaceItems(uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        // Count active items
        uint256 activeCount = 0;
        uint256 totalItems = _itemIdCounter.current();
        
        for (uint256 i = 1; i <= totalItems && activeCount < offset + limit; i++) {
            if (marketplaceItems[i].status == ItemStatus.LISTED) {
                activeCount++;
            }
        }
        
        // Adjust activeCount to not go below offset
        if (activeCount <= offset) {
            return new uint256[](0);
        }
        
        // Calculate actual count
        uint256 resultCount = activeCount - offset;
        if (resultCount > limit) {
            resultCount = limit;
        }
        
        // Create result array
        uint256[] memory result = new uint256[](resultCount);
        uint256 resultIndex = 0;
        activeCount = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= totalItems && resultIndex < resultCount; i++) {
            if (marketplaceItems[i].status == ItemStatus.LISTED) {
                if (activeCount >= offset) {
                    result[resultIndex] = i;
                    resultIndex++;
                }
                activeCount++;
            }
        }
        
        return result;
    }
    
    // Search marketplace items by name
    function searchMarketplaceItems(string memory searchTerm) 
        external 
        view 
        returns (uint256[] memory) 
    {
        require(bytes(searchTerm).length > 0, "Search term cannot be empty");
        
        // Count matching items (limit to 100 for gas efficiency)
        uint256 matchCount = 0;
        uint256 totalItems = _itemIdCounter.current();
        uint256[] memory matches = new uint256[](100);
        
        for (uint256 i = 1; i <= totalItems && matchCount < 100; i++) {
            MarketplaceItem storage item = marketplaceItems[i];
            
            // Only include active items
            if (item.status == ItemStatus.LISTED) {
                // Check if name contains search term
                if (containsSubstring(item.name, searchTerm)) {
                    matches[matchCount] = i;
                    matchCount++;
                }
            }
        }
        
        // Create result array with actual size
        uint256[] memory result = new uint256[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            result[i] = matches[i];
        }
        
        return result;
    }
    
    // ==================== TRADING SYSTEM ====================
    
    // Structure for trade offer
    struct TradeOffer {
        uint256 id;
        address initiator;
        address recipient;
        uint256[] initiatorItemIds;
        uint256[] recipientItemIds;
        uint256 initiatorTokenAmount;
        uint256 recipientTokenAmount;
        uint256 creationTime;
        uint256 expirationTime;
        TradeStatus status;
        string message;
        uint256 completionTime;
    }
    
    // Enum for trade status
    enum TradeStatus { PENDING, ACCEPTED, REJECTED, CANCELLED, EXPIRED, COMPLETED }
    
    // Mapping for trade offers
    mapping(uint256 => TradeOffer) public tradeOffers;
    mapping(address => uint256[]) public userInitiatedTrades;
    mapping(address => uint256[]) public userReceivedTrades;
    
    // Counter for trade offers
    Counters.Counter private _tradeOfferIdCounter;
    
    // Events for trading
    event TradeOfferCreated(uint256 indexed tradeId, address indexed initiator, address indexed recipient);
    event TradeOfferStatusChanged(uint256 indexed tradeId, TradeStatus status);
    event TradeCompleted(uint256 indexed tradeId, address indexed initiator, address indexed recipient);
    
    // Create trade offer
    function createTradeOffer(
        address recipient,
        uint256[] calldata initiatorItemIds,
        uint256[] calldata recipientItemIds,
        uint256 recipientTokenAmount,
        string memory message,
        uint256 expirationTime
    ) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
        withinBatchLimit(initiatorItemIds.length)
        withinBatchLimit(recipientItemIds.length)
    {
        require(recipient != address(0), "Invalid recipient address");
        require(recipient != msg.sender, "Cannot trade with self");
        require(isRegistered[recipient], "Recipient not registered");
        require(expirationTime > block.timestamp, "Expiration time must be in the future");
        
        // Validate initiator items
        for (uint256 i = 0; i < initiatorItemIds.length; i++) {
            uint256 itemId = initiatorItemIds[i];
            require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid initiator item ID");
            
            MarketplaceItem storage item = marketplaceItems[itemId];
            require(item.seller == msg.sender, "Not the owner of initiator item");
            require(item.status == ItemStatus.LISTED, "Initiator item not available");
            require(item.quantity > 0, "Initiator item out of stock");
        }
        
        // Validate recipient items
        for (uint256 i = 0; i < recipientItemIds.length; i++) {
            uint256 itemId = recipientItemIds[i];
            require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid recipient item ID");
            
            MarketplaceItem storage item = marketplaceItems[itemId];
            require(item.seller == recipient, "Not the owner of recipient item");
            require(item.status == ItemStatus.LISTED, "Recipient item not available");
            require(item.quantity > 0, "Recipient item out of stock");
        }
        
        // Increment trade offer ID counter
        _tradeOfferIdCounter.increment();
        uint256 newTradeId = _tradeOfferIdCounter.current();
        
        // Create new trade offer
        TradeOffer storage newTrade = tradeOffers[newTradeId];
        newTrade.id = newTradeId;
        newTrade.initiator = msg.sender;
        newTrade.recipient = recipient;
        newTrade.creationTime = block.timestamp;
        newTrade.expirationTime = expirationTime;
        newTrade.status = TradeStatus.PENDING;
        newTrade.message = message;
        newTrade.initiatorTokenAmount = msg.value;
        newTrade.recipientTokenAmount = recipientTokenAmount;
        
        // Add item IDs
        for (uint256 i = 0; i < initiatorItemIds.length; i++) {
            newTrade.initiatorItemIds.push(initiatorItemIds[i]);
        }
        
        for (uint256 i = 0; i < recipientItemIds.length; i++) {
            newTrade.recipientItemIds.push(recipientItemIds[i]);
        }
        
        // Add to user's trades
        userInitiatedTrades[msg.sender].push(newTradeId);
        userReceivedTrades[recipient].push(newTradeId);
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("trade", newTradeId));
        createNotification(
            recipient,
            "TRADE_OFFER_RECEIVED",
            entityId,
            string(abi.encodePacked("You have received a new trade offer from ", userProfiles[msg.sender].name))
        );
        
        emit TradeOfferCreated(newTradeId, msg.sender, recipient);
    }
    
    // Accept trade offer
    function acceptTradeOffer(uint256 tradeId) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(tradeId > 0 && tradeId <= _tradeOfferIdCounter.current(), "Invalid trade ID");
        
        TradeOffer storage trade = tradeOffers[tradeId];
        require(trade.recipient == msg.sender, "Not the trade recipient");
        require(trade.status == TradeStatus.PENDING, "Trade not pending");
        require(block.timestamp <= trade.expirationTime, "Trade offer expired");
        
        // Check recipient token amount
        if (trade.recipientTokenAmount > 0) {
            require(msg.value >= trade.recipientTokenAmount, "Insufficient token amount");
        }
        
        // Verify all items are still available
        for (uint256 i = 0; i < trade.initiatorItemIds.length; i++) {
            uint256 itemId = trade.initiatorItemIds[i];
            MarketplaceItem storage item = marketplaceItems[itemId];
            
            require(item.seller == trade.initiator, "Initiator no longer owns item");
            require(item.status == ItemStatus.LISTED, "Initiator item not available");
            require(item.quantity > 0, "Initiator item out of stock");
        }
        
        for (uint256 i = 0; i < trade.recipientItemIds.length; i++) {
            uint256 itemId = trade.recipientItemIds[i];
            MarketplaceItem storage item = marketplaceItems[itemId];
            
            require(item.seller == trade.recipient, "Recipient no longer owns item");
            require(item.status == ItemStatus.LISTED, "Recipient item not available");
            require(item.quantity > 0, "Recipient item out of stock");
        }
        
        // Process the trade
        // 1. Transfer initiator items to recipient
        for (uint256 i = 0; i < trade.initiatorItemIds.length; i++) {
            uint256 itemId = trade.initiatorItemIds[i];
            MarketplaceItem storage item = marketplaceItems[itemId];
            
            // Change item owner
            item.seller = trade.recipient;
            item.lastUpdateTime = block.timestamp;
            
            // Remove from initiator's items
            for (uint256 j = 0; j < sellerItems[trade.initiator].length; j++) {
                if (sellerItems[trade.initiator][j] == itemId) {
                    sellerItems[trade.initiator][j] = sellerItems[trade.initiator][sellerItems[trade.initiator].length - 1];
                    sellerItems[trade.initiator].pop();
                    break;
                }
            }
            
            // Add to recipient's items
            sellerItems[trade.recipient].push(itemId);
        }
        
        // 2. Transfer recipient items to initiator
        for (uint256 i = 0; i < trade.recipientItemIds.length; i++) {
            uint256 itemId = trade.recipientItemIds[i];
            MarketplaceItem storage item = marketplaceItems[itemId];
            
            // Change item owner
            item.seller = trade.initiator;
            item.lastUpdateTime = block.timestamp;
            
            // Remove from recipient's items
            for (uint256 j = 0; j < sellerItems[trade.recipient].length; j++) {
                if (sellerItems[trade.recipient][j] == itemId) {
                    sellerItems[trade.recipient][j] = sellerItems[trade.recipient][sellerItems[trade.recipient].length - 1];
                    sellerItems[trade.recipient].pop();
                    break;
                }
            }
            
            // Add to initiator's items
            sellerItems[trade.initiator].push(itemId);
        }
        
        // 3. Transfer tokens
        if (trade.initiatorTokenAmount > 0) {
            userBalances[trade.recipient] = userBalances[trade.recipient].add(trade.initiatorTokenAmount);
        }
        
        if (trade.recipientTokenAmount > 0) {
            userBalances[trade.initiator] = userBalances[trade.initiator].add(trade.recipientTokenAmount);
        }
        
        // 4. Refund excess payment
        if (msg.value > trade.recipientTokenAmount) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(trade.recipientTokenAmount));
        }
        
        // Update trade status
        trade.status = TradeStatus.COMPLETED;
        trade.completionTime = block.timestamp;
        
        // Create notifications
        bytes32 entityId1 = keccak256(abi.encodePacked("trade", tradeId, "accepted"));
        createNotification(
            trade.initiator,
            "TRADE_OFFER_ACCEPTED",
            entityId1,
            string(abi.encodePacked("Your trade offer has been accepted by ", userProfiles[trade.recipient].name))
        );
        
        emit TradeOfferStatusChanged(tradeId, TradeStatus.COMPLETED);
        emit TradeCompleted(tradeId, trade.initiator, trade.recipient);
    }
    
    // Reject trade offer
    function rejectTradeOffer(uint256 tradeId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(tradeId > 0 && tradeId <= _tradeOfferIdCounter.current(), "Invalid trade ID");
        
        TradeOffer storage trade = tradeOffers[tradeId];
        require(trade.recipient == msg.sender, "Not the trade recipient");
        require(trade.status == TradeStatus.PENDING, "Trade not pending");
        
        // Update trade status
        trade.status = TradeStatus.REJECTED;
        
        // Refund initiator token amount
        if (trade.initiatorTokenAmount > 0) {
            userBalances[trade.initiator] = userBalances[trade.initiator].add(trade.initiatorTokenAmount);
        }
        
        // Create notification for initiator
        bytes32 entityId = keccak256(abi.encodePacked("trade", tradeId, "rejected"));
        createNotification(
            trade.initiator,
            "TRADE_OFFER_REJECTED",
            entityId,
            string(abi.encodePacked("Your trade offer has been rejected by ", userProfiles[trade.recipient].name))
        );
        
        emit TradeOfferStatusChanged(tradeId, TradeStatus.REJECTED);
    }
    
    // Cancel trade offer
    function cancelTradeOffer(uint256 tradeId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(tradeId > 0 && tradeId <= _tradeOfferIdCounter.current(), "Invalid trade ID");
        
        TradeOffer storage trade = tradeOffers[tradeId];
        require(trade.initiator == msg.sender, "Not the trade initiator");
        require(trade.status == TradeStatus.PENDING, "Trade not pending");
        
        // Update trade status
        trade.status = TradeStatus.CANCELLED;
        
        // Refund initiator token amount
        if (trade.initiatorTokenAmount > 0) {
            userBalances[msg.sender] = userBalances[msg.sender].add(trade.initiatorTokenAmount);
        }
        
        // Create notification for recipient
        bytes32 entityId = keccak256(abi.encodePacked("trade", tradeId, "cancelled"));
        createNotification(
            trade.recipient,
            "TRADE_OFFER_CANCELLED",
            entityId,
            string(abi.encodePacked("A trade offer from ", userProfiles[msg.sender].name, " has been cancelled"))
        );
        
        emit TradeOfferStatusChanged(tradeId, TradeStatus.CANCELLED);
    }
    
    // Check and process expired trades
    function processExpiredTrade(uint256 tradeId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(tradeId > 0 && tradeId <= _tradeOfferIdCounter.current(), "Invalid trade ID");
        
        TradeOffer storage trade = tradeOffers[tradeId];
        require(trade.status == TradeStatus.PENDING, "Trade not pending");
        require(block.timestamp > trade.expirationTime, "Trade not expired");
        
        // Update trade status
        trade.status = TradeStatus.EXPIRED;
        
        // Refund initiator token amount
        if (trade.initiatorTokenAmount > 0) {
            userBalances[trade.initiator] = userBalances[trade.initiator].add(trade.initiatorTokenAmount);
        }
        
        // Create notifications
        bytes32 entityId1 = keccak256(abi.encodePacked("trade", tradeId, "expired", "initiator"));
        createNotification(
            trade.initiator,
            "TRADE_OFFER_EXPIRED",
            entityId1,
            string(abi.encodePacked("Your trade offer has expired"))
        );
        
        bytes32 entityId2 = keccak256(abi.encodePacked("trade", tradeId, "expired", "recipient"));
        createNotification(
            trade.recipient,
            "TRADE_OFFER_EXPIRED",
            entityId2,
            string(abi.encodePacked("A trade offer from ", userProfiles[trade.initiator].name, " has expired"))
        );
        
        emit TradeOfferStatusChanged(tradeId, TradeStatus.EXPIRED);
    }
    
    // Get trade offer details
    function getTradeOfferDetails(uint256 tradeId) 
        external 
        view 
        returns (
            address initiator,
            address recipient,
            uint256[] memory initiatorItemIds,
            uint256[] memory recipientItemIds,
            uint256 initiatorTokenAmount,
            uint256 recipientTokenAmount,
            uint256 creationTime,
            uint256 expirationTime,
            TradeStatus status,
            string memory message,
            uint256 completionTime
        ) 
    {
        require(tradeId > 0 && tradeId <= _tradeOfferIdCounter.current(), "Invalid trade ID");
        
        TradeOffer storage trade = tradeOffers[tradeId];
        
        return (
            trade.initiator,
            trade.recipient,
            trade.initiatorItemIds,
            trade.recipientItemIds,
            trade.initiatorTokenAmount,
            trade.recipientTokenAmount,
            trade.creationTime,
            trade.expirationTime,
            trade.status,
            trade.message,
            trade.completionTime
        );
    }
    
    // Get user initiated trades
    function getUserInitiatedTrades(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userInitiatedTrades[user];
    }
    
    // Get user received trades
    function getUserReceivedTrades(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userReceivedTrades[user];
    }
    
    // ==================== AUCTION SYSTEM ====================
    
    // Structure for auction
    struct Auction {
        uint256 id;
        uint256 itemId;
        address seller;
        uint256 startingPrice;
        uint256 currentPrice;
        address highestBidder;
        uint256 startTime;
        uint256 endTime;
        bool hasReservePrice;
        uint256 reservePrice;
        AuctionStatus status;
        uint256 minBidIncrement;
        uint256 bidCount;
        uint256 completionTime;
    }
    
    // Structure for auction bid
    struct AuctionBid {
        uint256 auctionId;
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool outbid;
    }
    
    // Enum for auction status
    enum AuctionStatus { PENDING, ACTIVE, ENDED, CANCELLED, COMPLETED, FAILED }
    
    // Mapping for auctions
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => AuctionBid[])) public auctionBids;
    mapping(uint256 => address[]) public auctionBidders;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => uint256[]) public userBidAuctions;
    
    // Counter for auctions
    Counters.Counter private _auctionIdCounter;
    
    // Events for auctions
    event AuctionCreated(uint256 indexed auctionId, uint256 indexed itemId, address indexed seller, uint256 startingPrice);
    event AuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event AuctionCancelled(uint256 indexed auctionId);
    
    // Create auction
    function createAuction(
        uint256 itemId,
        uint256 startingPrice,
        uint256 duration,
        uint256 minBidIncrement,
        bool hasReservePrice,
        uint256 reservePrice
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(minBidIncrement > 0, "Minimum bid increment must be greater than 0");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.seller == msg.sender, "Not the item owner");
        require(item.status == ItemStatus.LISTED, "Item not available");
        require(item.quantity > 0, "Item out of stock");
        
        // Validate reserve price
        if (hasReservePrice) {
            require(reservePrice > startingPrice, "Reserve price must be greater than starting price");
        } else {
            reservePrice = 0;
        }
        
        // Calculate end time
        uint256 endTime = block.timestamp + duration;
        
        // Increment auction ID counter
        _auctionIdCounter.increment();
        uint256 newAuctionId = _auctionIdCounter.current();
        
        // Create new auction
        Auction storage newAuction = auctions[newAuctionId];
        newAuction.id = newAuctionId;
        newAuction.itemId = itemId;
        newAuction.seller = msg.sender;
        newAuction.startingPrice = startingPrice;
        newAuction.currentPrice = startingPrice;
        newAuction.startTime = block.timestamp;
        newAuction.endTime = endTime;
        newAuction.hasReservePrice = hasReservePrice;
        newAuction.reservePrice = reservePrice;
        newAuction.status = AuctionStatus.ACTIVE;
        newAuction.minBidIncrement = minBidIncrement;
        
        // Update item status
        item.status = ItemStatus.RESERVED;
        
        // Add to user's auctions
        userAuctions[msg.sender].push(newAuctionId);
        
        // Pay listing fee
        uint256 listingFee = 0.01 ether;
        require(userBalances[msg.sender] >= listingFee, "Insufficient balance for listing fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(listingFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(listingFee);
        
        emit FeePaid(msg.sender, listingFee, "Auction Listing");
        emit AuctionCreated(newAuctionId, itemId, msg.sender, startingPrice);
    }
    
    // Place bid on auction
    function placeBid(uint256 auctionId) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        require(msg.value > 0, "Bid amount must be greater than 0");
        
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(auction.seller != msg.sender, "Cannot bid on own auction");
        
        // Check if bid is high enough
        uint256 minBid = auction.currentPrice.add(auction.minBidIncrement);
        require(msg.value >= minBid, "Bid too low");
        
        // Refund previous highest bidder if exists
        if (auction.highestBidder != address(0)) {
            // Mark previous bid as outbid
            AuctionBid[] storage bidderBids = auctionBids[auctionId][auction.highestBidder];
            if (bidderBids.length > 0) {
                bidderBids[bidderBids.length - 1].outbid = true;
            }
            
            // Refund previous highest bidder
            userBalances[auction.highestBidder] = userBalances[auction.highestBidder].add(auction.currentPrice);
            
            // Create notification for outbid bidder
            bytes32 entityId = keccak256(abi.encodePacked("auction", auctionId, "outbid", auction.highestBidder));
            createNotification(
                auction.highestBidder,
                "AUCTION_OUTBID",
                entityId,
                string(abi.encodePacked("You have been outbid on auction for item: ", marketplaceItems[auction.itemId].name))
            );
        }
        
        // Update auction
        auction.currentPrice = msg.value;
        auction.highestBidder = msg.sender;
        auction.bidCount += 1;
        
        // Create and store bid
        AuctionBid memory newBid = AuctionBid({
            auctionId: auctionId,
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            outbid: false
        });
        
        auctionBids[auctionId][msg.sender].push(newBid);
        
        // Add bidder to auction bidders if not already added
        bool isBidderAdded = false;
        for (uint256 i = 0; i < auctionBidders[auctionId].length; i++) {
            if (auctionBidders[auctionId][i] == msg.sender) {
                isBidderAdded = true;
                break;
            }
        }
        
        if (!isBidderAdded) {
            auctionBidders[auctionId].push(msg.sender);
            
            // Add to user's bid auctions
            userBidAuctions[msg.sender].push(auctionId);
        }
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("auction", auctionId, "bid", msg.sender));
        createNotification(
            auction.seller,
            "AUCTION_BID_PLACED",
            entityId,
            string(abi.encodePacked("A new bid of ", msg.value.toString(), " wei has been placed on your auction"))
        );
        
        emit AuctionBidPlaced(auctionId, msg.sender, msg.value);
    }
    
    // End auction
    function endAuction(uint256 auctionId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        
        // Check if caller is seller or if auction has ended
        require(
            auction.seller == msg.sender || block.timestamp >= auction.endTime,
            "Only seller can end before deadline"
        );
        
        // Process auction end
        MarketplaceItem storage item = marketplaceItems[auction.itemId];
        
        if (auction.highestBidder != address(0)) {
            // Auction has bids
            bool reservePriceMet = true;
            
            // Check if reserve price is met
            if (auction.hasReservePrice && auction.currentPrice < auction.reservePrice) {
                reservePriceMet = false;
            }
            
            if (reservePriceMet) {
                // Successful auction
                auction.status = AuctionStatus.COMPLETED;
                auction.completionTime = block.timestamp;
                
                // Calculate platform fee
                uint256 platformFeeAmount = (auction.currentPrice.mul(platformFee)).div(FEE_DENOMINATOR);
                uint256 sellerAmount = auction.currentPrice.sub(platformFeeAmount);
                
                // Transfer funds to seller
                userBalances[auction.seller] = userBalances[auction.seller].add(sellerAmount);
                userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
                
                // Transfer item ownership
                item.seller = auction.highestBidder;
                item.status = ItemStatus.LISTED;
                
                // Update seller items
                for (uint256 i = 0; i < sellerItems[auction.seller].length; i++) {
                    if (sellerItems[auction.seller][i] == auction.itemId) {
                        sellerItems[auction.seller][i] = sellerItems[auction.seller][sellerItems[auction.seller].length - 1];
                        sellerItems[auction.seller].pop();
                        break;
                    }
                }
                
                // Add to new owner's items
                sellerItems[auction.highestBidder].push(auction.itemId);
                
                // Create notifications
                bytes32 entityId1 = keccak256(abi.encodePacked("auction", auctionId, "completed", "seller"));
                createNotification(
                    auction.seller,
                    "AUCTION_COMPLETED",
                    entityId1,
                    string(abi.encodePacked("Your auction has completed successfully for ", auction.currentPrice.toString(), " wei"))
                );
                
                bytes32 entityId2 = keccak256(abi.encodePacked("auction", auctionId, "completed", "winner"));
                createNotification(
                    auction.highestBidder,
                    "AUCTION_WON",
                    entityId2,
                    string(abi.encodePacked("You won the auction for ", item.name))
                );
                
                emit AuctionEnded(auctionId, auction.highestBidder, auction.currentPrice);
                emit FeePaid(auction.seller, platformFeeAmount, "Auction Fee");
            } else {
                // Reserve price not met
                auction.status = AuctionStatus.FAILED;
                auction.completionTime = block.timestamp;
                
                // Refund highest bidder
                userBalances[auction.highestBidder] = userBalances[auction.highestBidder].add(auction.currentPrice);
                
                // Restore item status
                item.status = ItemStatus.LISTED;
                
                // Create notifications
                bytes32 entityId1 = keccak256(abi.encodePacked("auction", auctionId, "failed", "reserve", "seller"));
                createNotification(
                    auction.seller,
                    "AUCTION_FAILED",
                    entityId1,
                    string(abi.encodePacked("Your auction failed as the reserve price was not met"))
                );
                
                bytes32 entityId2 = keccak256(abi.encodePacked("auction", auctionId, "failed", "reserve", "bidder"));
                createNotification(
                    auction.highestBidder,
                    "AUCTION_FAILED",
                    entityId2,
                    string(abi.encodePacked("The auction for ", item.name, " failed as the reserve price was not met"))
                );
                
                emit AuctionEnded(auctionId, address(0), 0);
            }
        } else {
            // No bids
            auction.status = AuctionStatus.FAILED;
            auction.completionTime = block.timestamp;
            
            // Restore item status
            item.status = ItemStatus.LISTED;
            
            // Create notification for seller
            bytes32 entityId = keccak256(abi.encodePacked("auction", auctionId, "failed", "nobids"));
            createNotification(
                auction.seller,
                "AUCTION_FAILED",
                entityId,
                string(abi.encodePacked("Your auction ended with no bids"))
            );
            
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }
    
    // Cancel auction
    function cancelAuction(uint256 auctionId) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        
        Auction storage auction = auctions[auctionId];
        require(auction.seller == msg.sender || msg.sender == owner(), "Not authorized");
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        
        // Can only cancel if no bids or owner
        if (msg.sender == auction.seller) {
            require(auction.bidCount == 0, "Cannot cancel auction with bids");
        }
        
        // Update auction status
        auction.status = AuctionStatus.CANCELLED;
        auction.completionTime = block.timestamp;
        
        // Restore item status
        MarketplaceItem storage item = marketplaceItems[auction.itemId];
        item.status = ItemStatus.LISTED;
        
        // Refund highest bidder if exists
        if (auction.highestBidder != address(0)) {
            userBalances[auction.highestBidder] = userBalances[auction.highestBidder].add(auction.currentPrice);
            
            // Create notification for highest bidder
            bytes32 entityId = keccak256(abi.encodePacked("auction", auctionId, "cancelled", "bidder"));
            createNotification(
                auction.highestBidder,
                "AUCTION_CANCELLED",
                entityId,
                string(abi.encodePacked("An auction you bid on has been cancelled"))
            );
        }
        
        emit AuctionCancelled(auctionId);
    }
    
    // Extend auction time
    function extendAuctionTime(uint256 auctionId, uint256 additionalTime) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        require(additionalTime > 0, "Additional time must be greater than 0");
        
        Auction storage auction = auctions[auctionId];
        require(auction.seller == msg.sender, "Not the auction seller");
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction already ended");
        
        // Extend end time
        auction.endTime = auction.endTime.add(additionalTime);
        
        // Create notification for bidders
        for (uint256 i = 0; i < auctionBidders[auctionId].length; i++) {
            address bidder = auctionBidders[auctionId][i];
            
            bytes32 entityId = keccak256(abi.encodePacked("auction", auctionId, "extended", bidder));
            createNotification(
                bidder,
                "AUCTION_EXTENDED",
                entityId,
                string(abi.encodePacked("An auction you bid on has been extended by ", additionalTime.toString(), " seconds"))
            );
        }
    }
    
    // Get auction details
    function getAuctionDetails(uint256 auctionId) 
        external 
        view 
        returns (
            uint256 itemId,
            address seller,
            uint256 startingPrice,
            uint256 currentPrice,
            address highestBidder,
            uint256 startTime,
            uint256 endTime,
            bool hasReservePrice,
            uint256 reservePrice,
            AuctionStatus status,
            uint256 minBidIncrement,
            uint256 bidCount
        ) 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        
        Auction storage auction = auctions[auctionId];
        
        // Hide reserve price if not seller and auction is active
        uint256 viewableReservePrice = auction.reservePrice;
        if (auction.hasReservePrice && auction.status == AuctionStatus.ACTIVE && msg.sender != auction.seller) {
            viewableReservePrice = 0;
        }
        
        return (
            auction.itemId,
            auction.seller,
            auction.startingPrice,
            auction.currentPrice,
            auction.highestBidder,
            auction.startTime,
            auction.endTime,
            auction.hasReservePrice,
            viewableReservePrice,
            auction.status,
            auction.minBidIncrement,
            auction.bidCount
        );
    }
    
    // Get auction bidders
    function getAuctionBidders(uint256 auctionId) 
        external 
        view 
        returns (address[] memory) 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        
        return auctionBidders[auctionId];
    }
    
    // Get user bids for an auction
    function getUserBidsForAuction(uint256 auctionId, address user) 
        external 
        view 
        returns (
            uint256[] memory amounts,
            uint256[] memory timestamps,
            bool[] memory outbids
        ) 
    {
        require(auctionId > 0 && auctionId <= _auctionIdCounter.current(), "Invalid auction ID");
        
        AuctionBid[] storage userBids = auctionBids[auctionId][user];
        uint256 length = userBids.length;
        
        amounts = new uint256[](length);
        timestamps = new uint256[](length);
        outbids = new bool[](length);
        
        for (uint256 i = 0; i < length; i++) {
            amounts[i] = userBids[i].amount;
            timestamps[i] = userBids[i].timestamp;
            outbids[i] = userBids[i].outbid;
        }
        
        return (amounts, timestamps, outbids);
    }
    
    // Get user auctions
    function getUserAuctions(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userAuctions[user];
    }
    
    // Get auctions user has bid on
    function getUserBidAuctions(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userBidAuctions[user];
    }
    
    // Get active auctions (paginated)
    function getActiveAuctions(uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        // Count active auctions
        uint256 activeCount = 0;
        uint256 totalAuctions = _auctionIdCounter.current();
        
        for (uint256 i = 1; i <= totalAuctions && activeCount < offset + limit; i++) {
            if (auctions[i].status == AuctionStatus.ACTIVE) {
                activeCount++;
            }
        }
        
        // Adjust activeCount to not go below offset
        if (activeCount <= offset) {
            return new uint256[](0);
        }
        
        // Calculate actual count
        uint256 resultCount = activeCount - offset;
        if (resultCount > limit) {
            resultCount = limit;
        }
        
        // Create result array
        uint256[] memory result = new uint256[](resultCount);
        uint256 resultIndex = 0;
        activeCount = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= totalAuctions && resultIndex < resultCount; i++) {
            if (auctions[i].status == AuctionStatus.ACTIVE) {
                if (activeCount >= offset) {
                    result[resultIndex] = i;
                    resultIndex++;
                }
                activeCount++;
            }
        }
        
        return result;
    }
    
    // Get auctions ending soon
    function getAuctionsEndingSoon(uint256 timeWindow, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        require(timeWindow > 0, "Time window must be greater than 0");
        
        // Define ending soon window
        uint256 endingSoonCutoff = block.timestamp + timeWindow;
        
        // Count auctions ending soon
        uint256 endingSoonCount = 0;
        uint256 totalAuctions = _auctionIdCounter.current();
        
        for (uint256 i = 1; i <= totalAuctions && endingSoonCount < limit; i++) {
            Auction storage auction = auctions[i];
            if (auction.status == AuctionStatus.ACTIVE && auction.endTime <= endingSoonCutoff) {
                endingSoonCount++;
            }
        }
        
        // Create result array
        uint256[] memory result = new uint256[](endingSoonCount);
        uint256 resultIndex = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= totalAuctions && resultIndex < endingSoonCount; i++) {
            Auction storage auction = auctions[i];
            if (auction.status == AuctionStatus.ACTIVE && auction.endTime <= endingSoonCutoff) {
                result[resultIndex] = i;
                resultIndex++;
            }
        }
        
        return result;
    }
    
    // ==================== DUTCH AUCTION SYSTEM ====================
    
    // Structure for Dutch auction
    struct DutchAuction {
        uint256 id;
        uint256 itemId;
        address seller;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentPrice;
        uint256 priceDecrementAmount;
        uint256 priceDecrementInterval;
        uint256 lastPriceUpdateTime;
        uint256 startTime;
        uint256 endTime;
        AuctionStatus status;
        address winner;
        uint256 winningPrice;
        uint256 completionTime;
    }
    
    // Mapping for Dutch auctions
    mapping(uint256 => DutchAuction) public dutchAuctions;
    mapping(address => uint256[]) public userDutchAuctions;
    
    // Counter for Dutch auctions
    Counters.Counter private _dutchAuctionIdCounter;
    
    // Events for Dutch auctions
    event DutchAuctionCreated(uint256 indexed auctionId, uint256 indexed itemId, address indexed seller, uint256 startingPrice);
    event DutchAuctionPriceUpdated(uint256 indexed auctionId, uint256 newPrice);
    event DutchAuctionPurchased(uint256 indexed auctionId, address indexed buyer, uint256 price);
    event DutchAuctionEnded(uint256 indexed auctionId, bool successful);
    
    // Create Dutch auction
    function createDutchAuction(
        uint256 itemId,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 priceDecrementAmount,
        uint256 priceDecrementInterval,
        uint256 duration
    ) 
        external 
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "Invalid item ID");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(reservePrice > 0 && reservePrice < startingPrice, "Reserve price must be greater than 0 and less than starting price");
        require(priceDecrementAmount > 0, "Price decrement amount must be greater than 0");
        require(priceDecrementInterval > 0, "Price decrement interval must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        
        // Check that price can reach reserve price within duration
        uint256 totalDecrements = (startingPrice - reservePrice) / priceDecrementAmount;
        uint256 totalDecrementTime = totalDecrements * priceDecrementInterval;
        require(totalDecrementTime <= duration, "Price cannot reach reserve price within duration");
        
        MarketplaceItem storage item = marketplaceItems[itemId];
        require(item.seller == msg.sender, "Not the item owner");
        require(item.status == ItemStatus.LISTED, "Item not available");
        require(item.quantity > 0, "Item out of stock");
        
        // Calculate end time
        uint256 endTime = block.timestamp + duration;
        
        // Increment Dutch auction ID counter
        _dutchAuctionIdCounter.increment();
        uint256 newAuctionId = _dutchAuctionIdCounter.current();
        
        // Create new Dutch auction
        DutchAuction storage newAuction = dutchAuctions[newAuctionId];
        newAuction.id = newAuctionId;
        newAuction.itemId = itemId;
        newAuction.seller = msg.sender;
        newAuction.startingPrice = startingPrice;
        newAuction.reservePrice = reservePrice;
        newAuction.currentPrice = startingPrice;
        newAuction.priceDecrementAmount = priceDecrementAmount;
        newAuction.priceDecrementInterval = priceDecrementInterval;
        newAuction.lastPriceUpdateTime = block.timestamp;
        newAuction.startTime = block.timestamp;
        newAuction.endTime = endTime;
        newAuction.status = AuctionStatus.ACTIVE;
        
        // Update item status
        item.status = ItemStatus.RESERVED;
        
        // Add to user's Dutch auctions
        userDutchAuctions[msg.sender].push(newAuctionId);
        
        // Pay listing fee
        uint256 listingFee = 0.01 ether;
        require(userBalances[msg.sender] >= listingFee, "Insufficient balance for listing fee");
        
        userBalances[msg.sender] = userBalances[msg.sender].sub(listingFee);
        userBalances[feeCollector] = userBalances[feeCollector].add(listingFee);
        
        emit FeePaid(msg.sender, listingFee, "Dutch Auction Listing");
        emit DutchAuctionCreated(newAuctionId, itemId, msg.sender, startingPrice);
    }
    
    // Update Dutch auction price
    function updateDutchAuctionPrice(uint256 auctionId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(auctionId > 0 && auctionId <= _dutchAuctionIdCounter.current(), "Invalid auction ID");
        
        DutchAuction storage auction = dutchAuctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        
        // Calculate number of intervals passed
        uint256 timePassed = block.timestamp - auction.lastPriceUpdateTime;
        uint256 intervalsElapsed = timePassed / auction.priceDecrementInterval;
        
        // If no intervals elapsed, no need to update
        if (intervalsElapsed == 0) {
            return;
        }
        
        // Calculate new price
        uint256 totalDecrement = auction.priceDecrementAmount * intervalsElapsed;
        uint256 newPrice = auction.currentPrice;
        
        if (totalDecrement >= newPrice - auction.reservePrice) {
            // Price would go below reserve, set to reserve price
            newPrice = auction.reservePrice;
        } else {
            // Decrement price
            newPrice = newPrice - totalDecrement;
        }
        
        // Update auction
        auction.currentPrice = newPrice;
        auction.lastPriceUpdateTime = block.timestamp;
        
        emit DutchAuctionPriceUpdated(auctionId, newPrice);
    }
    
    // Purchase Dutch auction item
    function purchaseDutchAuctionItem(uint256 auctionId) 
        external 
        payable
        whenNotPaused 
        onlyRegistered 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _dutchAuctionIdCounter.current(), "Invalid auction ID");
        
        DutchAuction storage auction = dutchAuctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(auction.seller != msg.sender, "Cannot purchase own auction");
        
        // Update price before purchase
        // Calculate number of intervals passed
        uint256 timePassed = block.timestamp - auction.lastPriceUpdateTime;
        uint256 intervalsElapsed = timePassed / auction.priceDecrementInterval;
        
        // Calculate new price
        uint256 totalDecrement = auction.priceDecrementAmount * intervalsElapsed;
        uint256 currentPrice = auction.currentPrice;
        
        if (totalDecrement > 0) {
            if (totalDecrement >= currentPrice - auction.reservePrice) {
                // Price would go below reserve, set to reserve price
                currentPrice = auction.reservePrice;
            } else {
                // Decrement price
                currentPrice = currentPrice - totalDecrement;
            }
            
            // Update auction price
            auction.currentPrice = currentPrice;
            auction.lastPriceUpdateTime = block.timestamp;
        }
        
        // Check if payment is sufficient
        require(msg.value >= currentPrice, "Insufficient payment");
        
        // Update auction status
        auction.status = AuctionStatus.COMPLETED;
        auction.winner = msg.sender;
        auction.winningPrice = currentPrice;
        auction.completionTime = block.timestamp;
        
        MarketplaceItem storage item = marketplaceItems[auction.itemId];
        
        // Calculate platform fee
        uint256 platformFeeAmount = (currentPrice.mul(platformFee)).div(FEE_DENOMINATOR);
        uint256 sellerAmount = currentPrice.sub(platformFeeAmount);
        
        // Transfer funds
        userBalances[auction.seller] = userBalances[auction.seller].add(sellerAmount);
        userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
        
        // Refund excess payment
        if (msg.value > currentPrice) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value.sub(currentPrice));
        }
        
        // Transfer item ownership
        item.seller = msg.sender;
        item.status = ItemStatus.LISTED;
        
        // Update seller items
        for (uint256 i = 0; i < sellerItems[auction.seller].length; i++) {
            if (sellerItems[auction.seller][i] == auction.itemId) {
                sellerItems[auction.seller][i] = sellerItems[auction.seller][sellerItems[auction.seller].length - 1];
                sellerItems[auction.seller].pop();
                break;
            }
        }
        
        // Add to buyer's items
        sellerItems[msg.sender].push(auction.itemId);
        
        // Create notifications
        bytes32 entityId1 = keccak256(abi.encodePacked("dutchauction", auctionId, "sold", "seller"));
        createNotification(
            auction.seller,
            "DUTCH_AUCTION_SOLD",
            entityId1,
            string(abi.encodePacked("Your Dutch auction has been purchased for ", currentPrice.toString(), " wei"))
        );
        
        bytes32 entityId2 = keccak256(abi.encodePacked("dutchauction", auctionId, "purchased", "buyer"));
        createNotification(
            msg.sender,
            "DUTCH_AUCTION_PURCHASED",
            entityId2,
            string(abi.encodePacked("You purchased an item from a Dutch auction for ", currentPrice.toString(), " wei"))
        );
        
        emit DutchAuctionPurchased(auctionId, msg.sender, currentPrice);
        emit FeePaid(auction.seller, platformFeeAmount, "Dutch Auction Fee");
    }
    
    // End Dutch auction
    function endDutchAuction(uint256 auctionId) 
        external 
        whenNotPaused 
        nonReentrant 
        securityCheck 
    {
        require(auctionId > 0 && auctionId <= _dutchAuctionIdCounter.current(), "Invalid auction ID");
        
        DutchAuction storage auction = dutchAuctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "Auction not active");
        
        // Check if caller is seller or if auction has ended
        require(
            auction.seller == msg.sender || block.timestamp >= auction.endTime,
            "Only seller can end before deadline"
        );
        
        // Update auction status
        auction.status = AuctionStatus.ENDED;
        auction.completionTime = block.timestamp;
        
        // Restore item status
        MarketplaceItem storage item = marketplaceItems[auction.itemId];
        item.status = ItemStatus.LISTED;
        
        // Create notification for seller
        bytes32 entityId = keccak256(abi.encodePacked("dutchauction", auctionId, "ended"));
        createNotification(
            auction.seller,
            "DUTCH_AUCTION_ENDED",
            entityId,
            string(abi.encodePacked("Your Dutch auction has ended without a purchase"))
        );
        
        emit DutchAuctionEnded(auctionId, false);
    }
    
    // Get Dutch auction details
    function getDutchAuctionDetails(uint256 auctionId) 
        external 
        view 
        returns (
            uint256 itemId,
            address seller,
            uint256 startingPrice,
            uint256 reservePrice,
            uint256 currentPrice,
            uint256 priceDecrementAmount,
            uint256 priceDecrementInterval,
            uint256 startTime,
            uint256 endTime,
            AuctionStatus status,
            address winner,
            uint256 winningPrice
        ) 
    {
        require(auctionId > 0 && auctionId <= _dutchAuctionIdCounter.current(), "Invalid auction ID");
        
        DutchAuction storage auction = dutchAuctions[auctionId];
        
        // Calculate current price if active
        uint256 displayCurrentPrice = auction.currentPrice;
        
        if (auction.status == AuctionStatus.ACTIVE) {
            uint256 timePassed = block.timestamp - auction.lastPriceUpdateTime;
            uint256 intervalsElapsed = timePassed / auction.priceDecrementInterval;
            
            if (intervalsElapsed > 0) {
                uint256 totalDecrement = auction.priceDecrementAmount * intervalsElapsed;
                
                if (totalDecrement >= displayCurrentPrice - auction.reservePrice) {
                    displayCurrentPrice = auction.reservePrice;
                } else {
                    displayCurrentPrice = displayCurrentPrice - totalDecrement;
                }
            }
        }
        
        return (
            auction.itemId,
            auction.seller,
            auction.startingPrice,
            auction.reservePrice,
            displayCurrentPrice,
            auction.priceDecrementAmount,
            auction.priceDecrementInterval,
            auction.startTime,
            auction.endTime,
            auction.status,
            auction.winner,
            auction.winningPrice
        );
    }
    
    // Get user Dutch auctions
    function getUserDutchAuctions(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userDutchAuctions[user];
    }
    
    // Get active Dutch auctions (paginated)
    function getActiveDutchAuctions(uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory) 
    {
        // Count active Dutch auctions
        uint256 activeCount = 0;
        uint256 totalAuctions = _dutchAuctionIdCounter.current();
        
        for (uint256 i = 1; i <= totalAuctions && activeCount < offset + limit; i++) {
            if (dutchAuctions[i].status == AuctionStatus.ACTIVE) {
                activeCount++;
            }
        }
        
        // Adjust activeCount to not go below offset
        if (activeCount <= offset) {
            return new uint256[](0);
        }
        
        // Calculate actual count
        uint256 resultCount = activeCount - offset;
        if (resultCount > limit) {
            resultCount = limit;
        }
        
        // Create result array
        uint256[] memory result = new uint256[](resultCount);
        uint256 resultIndex = 0;
        activeCount = 0;
        
        // Fill result array
        for (uint256 i = 1; i <= totalAuctions && resultIndex < resultCount; i++) {
            if (dutchAuctions[i].status == AuctionStatus.ACTIVE) {
                if (activeCount >= offset) {
                    result[resultIndex] = i;
                    resultIndex++;
                }
                activeCount++;
            }
        }
        
        return result;
    }
    
// END OF PART 11/12 - CONTINUE TO PART 12/12
// SPDX-License-Identifier: MIT
// PART 12.1/12 - MonadEcosystemHubV1
// Advanced Features & Final Functions
// Continues from PART 11/12

// CONTINUED FROM PART 11/12

    // Reject a connection request
    function rejectConnection(address from)
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(from != address(0), "Invalid address");

        // Check if a PENDING connection request exists *from* the other user *to* msg.sender
        UserConnection storage connection = userConnections[from][msg.sender];
        require(connection.timestamp > 0, "No connection request from this user");
        require(connection.status == ConnectionStatus.PENDING, "Connection request not pending");

        // Reject connection (or simply delete the request)
        // Setting status to REJECTED keeps a record, deleting saves gas. Let's delete.
        delete userConnections[from][msg.sender];

        // Notify the original requester (optional)
        bytes32 entityId = keccak256(abi.encodePacked("connection", from, msg.sender, "rejected"));
        createNotification(
            from,
            "CONNECTION_REJECTED",
            entityId,
            string(abi.encodePacked(userProfiles[msg.sender].name, " rejected your connection request"))
         );


        emit ConnectionStatusChanged(from, msg.sender, ConnectionStatus.REJECTED);
    }

    // Block another user (prevents connection requests from them)
    function blockUser(address user)
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(user != address(0), "Invalid address to block");
        require(user != msg.sender, "Cannot block self");

        // Create or update the connection status *from sender to target* as BLOCKED
        UserConnection storage blockConnection = userConnections[msg.sender][user];
        ConnectionStatus oldStatus = blockConnection.status; // Store old status if needed

        blockConnection.from = msg.sender;
        blockConnection.to = user;
        blockConnection.timestamp = block.timestamp; // Time of blocking
        blockConnection.status = ConnectionStatus.BLOCKED;
        blockConnection.connectionType = "Blocked";

        // If they were previously connected, remove from connected lists
        if (oldStatus == ConnectionStatus.ACCEPTED) {
    address[] storage senderConnected = userConnectedUsers[msg.sender]; // <-- แก้ไข Type
    for (uint256 i = 0; i < senderConnected.length; i++) {
        if (senderConnected[i] == user) { // <-- การเปรียบเทียบจะถูกต้อง
                    senderConnected[i] = senderConnected[senderConnected.length - 1];
                    senderConnected.pop();
                    break;
                }
             }
             // Remove 'msg.sender' from 'user's list
             address[] storage targetConnected = userConnectedUsers[user]; // <-- แก้ไข Type
    for (uint256 i = 0; i < targetConnected.length; i++) {
        if (targetConnected[i] == msg.sender) {
                    targetConnected[i] = targetConnected[targetConnected.length - 1];
                    targetConnected.pop();
                    break;
                 }
             }
            // Also delete the reverse connection entry if it exists and was ACCEPTED
            delete userConnections[user][msg.sender];
        }
         // Also delete any pending request from the blocked user
         UserConnection storage pendingRequest = userConnections[user][msg.sender];
         if (pendingRequest.status == ConnectionStatus.PENDING) {
             delete userConnections[user][msg.sender];
         }


        emit ConnectionStatusChanged(msg.sender, user, ConnectionStatus.BLOCKED);
    }

    // Unblock a user
    function unblockUser(address user)
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(user != address(0), "Invalid address to unblock");

        // Check if the user is actually blocked by the sender
        UserConnection storage connection = userConnections[msg.sender][user];
        require(connection.timestamp > 0, "No connection record found");
        require(connection.status == ConnectionStatus.BLOCKED, "User is not blocked by you");

        // Remove the block record by deleting the connection entry
        delete userConnections[msg.sender][user];

        // Notify the unblocked user? (Optional)
        // ...

         // event UserUnblocked(address indexed blocker, address indexed unblocked);
         // emit UserUnblocked(msg.sender, user);
         // Using generic status change event might require a 'NONE' status
         // Let's just emit the fact that the block relationship changed.
         // We don't have a specific "unblocked" status.
         // emit ConnectionStatusChanged(msg.sender, user, ConnectionStatus.NONE); // Hypothetical NONE status
    }

    // Remove an accepted connection (unfriend/unfollow)
    function removeConnection(address user)
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(user != address(0), "Invalid address");

        // Check if an accepted connection exists between the two users
        UserConnection storage connection1 = userConnections[msg.sender][user];
        UserConnection storage connection2 = userConnections[user][msg.sender];

        require(connection1.status == ConnectionStatus.ACCEPTED || connection2.status == ConnectionStatus.ACCEPTED, "Users are not connected");

        // Delete connection entries in both directions
        delete userConnections[msg.sender][user];
        delete userConnections[user][msg.sender];

        // Remove from each other's connected lists
         address[] storage senderConnected = userConnectedUsers[msg.sender]; // <-- แก้ไข Type
for (uint256 i = 0; i < senderConnected.length; i++) {
   if (senderConnected[i] == user) {
                senderConnected[i] = senderConnected[senderConnected.length - 1];
                senderConnected.pop();
                break;
            }
         }
         address[] storage targetConnected = userConnectedUsers[user]; // <-- แก้ไข Type
for (uint256 i = 0; i < targetConnected.length; i++) {
    if (targetConnected[i] == msg.sender) {
                targetConnected[i] = targetConnected[targetConnected.length - 1];
                targetConnected.pop();
                break;
             }
         }

        // Notify the other user? (Optional)
        // ...

         // event ConnectionRemoved(address indexed user1, address indexed user2);
         // emit ConnectionRemoved(msg.sender, user);
    }

    // Get the status of a connection between two users
    function getConnectionStatus(address from, address to)
        external
        view
        returns (
            ConnectionStatus status, // Status from 'from's perspective
            uint256 timestamp,
            string memory connectionType
        )
    {
        UserConnection storage connection = userConnections[from][to];
        // Will return default values (PENDING=0, 0, "") if no connection record exists
        return (
            connection.status,
            connection.timestamp,
            connection.connectionType
        );
    }

    // Get the list of users connected to a specific user (status = ACCEPTED)
    function getConnectedUsers(address user)
        external
        view
        returns (address[] memory)
    {
        return userConnectedUsers[user];
    }

    // Check if two users have an accepted connection
    function areUsersConnected(address user1, address user2)
        external
        view
        returns (bool)
    {
        // Check both directions for an ACCEPTED status
        return userConnections[user1][user2].status == ConnectionStatus.ACCEPTED &&
               userConnections[user2][user1].status == ConnectionStatus.ACCEPTED;
    }


    // Structure for user notification

    // Event for user notification
    event NotificationCreated(uint256 id, address indexed recipient, string notificationType);
    event NotificationRead(uint256 id, address indexed recipient);

    // Create a notification for a user (internal function)
    function createNotification(
        address recipient,
        string memory notificationType,
        bytes32 entityId,
        string memory content
    )
        internal // Make internal as it's called by other functions
    {
        // Check user preferences before sending
        if (!userProfiles[recipient].preferences.receiveNotifications) {
            return; // User opted out
        }

        require(recipient != address(0), "Invalid recipient address for notification");
        // No need to check registration again if called internally after checks

        require(bytes(notificationType).length > 0, "Notification type cannot be empty");
        require(bytes(content).length > 0, "Notification content cannot be empty");

        // Get next notification ID for this specific user
        uint256 notificationId = userNotificationCount[recipient] + 1;

        // Create notification
        UserNotification storage notification = userNotifications[recipient][notificationId];
        notification.id = notificationId;
        notification.recipient = recipient; // Store for clarity if needed
        notification.notificationType = notificationType;
        notification.entityId = entityId;
        notification.content = content;
        notification.timestamp = block.timestamp;
        notification.isRead = false;

        // Update counts for the user
        userNotificationCount[recipient] = notificationId;
        userUnreadNotificationCount[recipient]++;

        emit NotificationCreated(notificationId, recipient, notificationType);
    }

    // Mark a specific notification as read
    function markNotificationAsRead(uint256 notificationId)
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
    {
        require(notificationId > 0 && notificationId <= userNotificationCount[msg.sender], "Invalid notification ID");

        UserNotification storage notification = userNotifications[msg.sender][notificationId];

        // Check if already read
        if (notification.isRead) {
            return; // Already read, do nothing
        }

        // Mark as read
        notification.isRead = true;

        // Update unread count safely
        if (userUnreadNotificationCount[msg.sender] > 0) {
            userUnreadNotificationCount[msg.sender]--;
        }

        emit NotificationRead(notificationId, msg.sender);
    }

    // Mark all notifications as read for the calling user
    function markAllNotificationsAsRead()
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
    {
        uint256 notificationCount = userNotificationCount[msg.sender];
        uint256 unreadCount = userUnreadNotificationCount[msg.sender];

        if (unreadCount == 0) {
            return; // Nothing to mark as read
        }

        // Iterate through notifications and mark unread ones
        // Optimization: Iterate backwards from latest might be faster if recent ones are unread
        for (uint256 i = notificationCount; i >= 1 && unreadCount > 0; i--) {
            UserNotification storage notification = userNotifications[msg.sender][i];
            if (!notification.isRead) {
                notification.isRead = true;
                unreadCount--; // Decrement remaining unread count
                // emit NotificationRead(i, msg.sender); // Emitting per notification might be too gassy
            }
        }

        // Reset unread count
        userUnreadNotificationCount[msg.sender] = 0;

        // Emit a single event for batch marking?
        // event AllNotificationsRead(address indexed user);
        // emit AllNotificationsRead(msg.sender);
    }

    // Get details of a specific notification for the calling user
    function getNotificationDetails(uint256 notificationId)
        external
        view
        returns (
            string memory notificationType,
            bytes32 entityId,
            string memory content,
            uint256 timestamp,
            bool isRead
        )
    {
        require(notificationId > 0 && notificationId <= userNotificationCount[msg.sender], "Invalid notification ID");
        UserNotification storage notification = userNotifications[msg.sender][notificationId];
        return (
            notification.notificationType,
            notification.entityId,
            notification.content,
            notification.timestamp,
            notification.isRead
        );
    }

    // Get user notifications with pagination (latest first)
    function getUserNotifications(uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory ids,
            string[] memory types,
            uint256[] memory timestamps,
            bool[] memory readStatuses,
            string[] memory contents // Include content
        )
    {
        uint256 notificationCount = userNotificationCount[msg.sender];

        if (offset >= notificationCount) {
            // Return empty arrays if offset is out of bounds
            ids = new uint256[](0);
            types = new string[](0);
            timestamps = new uint256[](0);
            readStatuses = new bool[](0);
            contents = new string[](0);
            return (ids, types, timestamps, readStatuses, contents);
        }

        // Calculate actual limit based on available notifications
        uint256 actualLimit = limit;
        uint256 firstIdToFetch = notificationCount - offset; // Latest ID minus offset
        uint256 lastIdToFetch = (notificationCount > offset + limit) ? notificationCount - offset - limit + 1 : 1;

         if (firstIdToFetch < lastIdToFetch) { // Handle potential underflow/edge case
             actualLimit = 0;
         } else {
             actualLimit = firstIdToFetch - lastIdToFetch + 1;
         }


        // Ensure limit doesn't exceed requested limit
        if (actualLimit > limit) {
            actualLimit = limit;
            lastIdToFetch = firstIdToFetch - limit + 1;
        }


        // Initialize result arrays
        ids = new uint256[](actualLimit);
        types = new string[](actualLimit);
        timestamps = new uint256[](actualLimit);
        readStatuses = new bool[](actualLimit);
        contents = new string[](actualLimit);

        // Fill arrays by iterating downwards from the latest relevant ID
        for (uint256 i = 0; i < actualLimit; i++) {
            uint256 notificationId = firstIdToFetch - i;
            UserNotification storage notification = userNotifications[msg.sender][notificationId];

            ids[i] = notification.id;
            types[i] = notification.notificationType;
            timestamps[i] = notification.timestamp;
            readStatuses[i] = notification.isRead;
            contents[i] = notification.content;
        }

        return (ids, types, timestamps, readStatuses, contents);
    }

    // Get the count of unread notifications for the calling user
    function getUnreadNotificationCount()
        external
        view
        returns (uint256)
    {
        return userUnreadNotificationCount[msg.sender];
    }

// END OF PART 12.1/12 - CONTINUE TO PART 12.2/12
// SPDX-License-Identifier: MIT
// PART 12.2/12 - MonadEcosystemHubV1
// Advanced Features & Final Functions
// Continues from PART 12.1/12

// CONTINUED FROM PART 12.1/12

    // Enum for achievement category
    

    // Event for user achievement
    event AchievementUnlocked(address indexed user, uint256 achievementId, string name);

    // Unlock an achievement for a user (internal function)
    function unlockAchievement(
        address user,
        string memory name,
        string memory description,
        uint256 points,
        string memory badgeURI,
        AchievementCategory category
    )
        internal // Called internally when criteria are met
    {
        require(user != address(0), "Invalid user address for achievement");
        require(isRegistered[user], "User not registered");
        require(bytes(name).length > 0, "Achievement name cannot be empty");
        require(bytes(description).length > 0, "Achievement description cannot be empty");
        require(points > 0, "Achievement points must be greater than 0");

        // Check if achievement already unlocked (by name, prevents duplicates)
        uint256 achievementCount = userAchievementCount[user];
        for (uint256 i = 1; i <= achievementCount; i++) {
            if (compareStrings(userAchievements[user][i].name, name)) {
                return; // Achievement already unlocked, do nothing
            }
        }

        // Get next achievement ID for this user
        uint256 achievementId = achievementCount + 1;

        // Create achievement record for the user
        UserAchievement storage achievement = userAchievements[user][achievementId];
        achievement.id = achievementId;
        achievement.name = name;
        achievement.description = description;
        achievement.unlockTimestamp = block.timestamp;
        achievement.points = points;
        achievement.badgeURI = badgeURI;
        achievement.category = category;

        // Update user's achievement counts and points
        userAchievementCount[user] = achievementId;
        userAchievementPoints[user] = userAchievementPoints[user].add(points);

        // Update user reputation based on achievement points
        userReputation[user] = userReputation[user].add(points); // Award reputation equal to points

        // Create notification for the user
        bytes32 entityId = keccak256(abi.encodePacked("achievement", user, achievementId));
        createNotification(
            user,
            "ACHIEVEMENT_UNLOCKED",
            entityId,
            string(abi.encodePacked("Achievement unlocked: ", name, " (+", points.toString(), " points!)"))
        );

        emit AchievementUnlocked(user, achievementId, name);
    }

    // Get all achievements unlocked by a user
    function getUserAchievements(address user)
        external
        view
        returns (
            uint256[] memory ids,
            string[] memory names,
            uint256[] memory timestamps,
            uint256[] memory pointsArray // Renamed from 'points' to avoid conflict
        )
    {
        uint256 achievementCount = userAchievementCount[user];

        ids = new uint256[](achievementCount);
        names = new string[](achievementCount);
        timestamps = new uint256[](achievementCount);
        pointsArray = new uint256[](achievementCount);

        for (uint256 i = 0; i < achievementCount; i++) {
            uint256 achievementId = i + 1; // Achievement IDs start from 1
            UserAchievement storage achievement = userAchievements[user][achievementId];

            ids[i] = achievement.id;
            names[i] = achievement.name;
            timestamps[i] = achievement.unlockTimestamp;
            pointsArray[i] = achievement.points;
        }

        return (ids, names, timestamps, pointsArray);
    }

    // Get details of a specific achievement unlocked by the calling user
    // Note: This gets details of an achievement the *user* has unlocked, not a global definition
    function getAchievementDetails(uint256 achievementId)
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 unlockTimestamp,
            uint256 points,
            string memory badgeURI,
            AchievementCategory category
        )
    {
        require(achievementId > 0 && achievementId <= userAchievementCount[msg.sender], "Invalid achievement ID for user");
        UserAchievement storage achievement = userAchievements[msg.sender][achievementId];
        return (
            achievement.name,
            achievement.description,
            achievement.unlockTimestamp,
            achievement.points,
            achievement.badgeURI,
            achievement.category
        );
    }

    // Get total achievement points for a user
    function getUserAchievementPoints(address user)
        external
        view
        returns (uint256)
    {
        return userAchievementPoints[user];
    }


    // Enum for rating category (can apply to different entities)
    enum RatingCategory { RESOURCE, EXCHANGE, GOVERNANCE, GAME, DATASET, USER, ITEM, ORDER }

    // Structure for user/entity rating
    struct UserRating {
        address rater;
        address ratedUser; // User being rated (or owner of entity being rated)
        uint256 timestamp;
        uint8 score; // e.g., 1-5 stars
        string comment;
        bytes32 entityId; // ID of the specific entity being rated (0 for user rating)
        RatingCategory category;
    }

    // Event for user/entity rating
    event UserRated(address indexed rater, address indexed ratedUser, uint8 score, bytes32 entityId, RatingCategory category);

    // Rate another user directly
    function rateUser(
        address user, // The user being rated
        uint8 score,
        string memory comment
    )
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(user != address(0), "Invalid user address to rate");
        require(user != msg.sender, "Cannot rate self");
        require(isRegistered[user], "Rated user is not registered");
        require(score >= 1 && score <= 5, "Score must be between 1 and 5");

        // Check if already rated this user directly (vs rating an entity they own)
        // A user can rate another user multiple times, but perhaps only the latest counts?
        // Or can rate different interactions? This simplified version allows overwriting.
        UserRating storage existingRating = userRatings[msg.sender][user]; // Store rating keyed by rater->rated
        bool isUpdate = existingRating.timestamp > 0 && existingRating.category == RatingCategory.USER; // Check if previous rating was a direct user rating

        // Update rating sum and count
        if (isUpdate) {
            // Adjust sum based on the change in score
            userRatingSum[user] = userRatingSum[user].sub(existingRating.score).add(score);
        } else {
            // New rating
            userRatingSum[user] = userRatingSum[user].add(score);
            userRatingCount[user] = userRatingCount[user].add(1);
            // Add rater to list if not already there (costly check)
            // bool foundRater = false;
            // for(uint i=0; i<userRaters[user].length; i++) { if(userRaters[user][i] == msg.sender) {foundRater = true; break;}}
            // if(!foundRater) userRaters[user].push(msg.sender);
        }

        // Create or update rating record
        UserRating storage rating = userRatings[msg.sender][user]; // Overwrites previous direct rating from this rater
        rating.rater = msg.sender;
        rating.ratedUser = user;
        rating.timestamp = block.timestamp;
        rating.score = score;
        rating.comment = comment;
        rating.entityId = bytes32(0); // 0 indicates direct user rating
        rating.category = RatingCategory.USER;

        // Update rated user's reputation based on score change
        int256 reputationChange = 0;
        if (score >= 4) reputationChange = 5; // Good rating
        else if (score <= 2) reputationChange = -5; // Bad rating
        else reputationChange = 1; // Neutral rating

        if (reputationChange > 0) {
            userReputation[user] = userReputation[user].add(uint256(reputationChange));
        } else if (reputationChange < 0) {
            if (userReputation[user] >= uint256(-reputationChange)) {
                userReputation[user] = userReputation[user].sub(uint256(-reputationChange));
            } else {
                 userReputation[user] = 0; // Prevent underflow
            }
        }
        // No change for neutral rating?


        // Notify the rated user
        bytes32 entityIdNotify = keccak256(abi.encodePacked("rating", msg.sender, user));
        createNotification(
            user,
            "USER_RATED",
            entityIdNotify,
            string(abi.encodePacked(userProfiles[msg.sender].name, " rated you ", uint256(score).toString(), " stars"))
        );

        emit UserRated(msg.sender, user, score, bytes32(0), RatingCategory.USER);
    }

    // Rate an entity (Resource, Item, Order, etc.) owned by another user
    function rateEntity(
        bytes32 entityId, // Use a unique ID for the entity (e.g., resourceId, orderId converted)
        RatingCategory category,
        uint8 score,
        string memory comment,
        address entityOwner // The owner of the entity being rated
    )
        external
        whenNotPaused
        onlyRegistered
        nonReentrant
        securityCheck // Apply security modifier
    {
        require(entityId != bytes32(0), "Invalid entity ID");
        require(entityOwner != address(0), "Invalid entity owner address");
        require(entityOwner != msg.sender, "Cannot rate own entity");
        require(isRegistered[entityOwner], "Entity owner not registered");
        require(score >= 1 && score <= 5, "Score must be between 1 and 5");
        require(category != RatingCategory.USER, "Use rateUser for direct user ratings");

        // TODO: Add validation specific to the entity category
        // e.g., if category is ORDER, check if msg.sender is the buyer of that order
        // Example: if (category == RatingCategory.ORDER) {
        //    uint256 orderId = uint256(entityId); // Risky cast, need safer conversion/mapping
        //    require(marketplaceOrders[orderId].buyer == msg.sender, "Not the buyer of this order");
        //    require(marketplaceOrders[orderId].status == OrderStatus.COMPLETED, "Order not completed");
        // }

        // Store rating keyed by rater->entityOwner AND entityId for uniqueness per entity
        // This means a user can rate multiple entities owned by the same person.
        // Alternative: Key by rater->entityId if entity ID is globally unique across types.
        // Let's key by rater -> entityOwner, but check entityId to allow multiple ratings for different entities.

        // Find if this rater already rated this specific entity owned by the ratedUser
        bool isUpdate = false;
        uint8 previousScore = 0;
        // This check is costly - requires iterating through rater's history or a dedicated mapping
        // mapping(address => mapping(bytes32 => UserRating)) entityRatings; // rater -> entityId -> Rating
        // if (entityRatings[msg.sender][entityId].timestamp > 0) {
        //     isUpdate = true;
        //     previousScore = entityRatings[msg.sender][entityId].score;
        // }
        // --- Simplified: Assume overwrite based on rater->ratedUser for now ---
         UserRating storage existingRating = userRatings[msg.sender][entityOwner];
         if (existingRating.timestamp > 0 && existingRating.entityId == entityId && existingRating.category == category) {
             isUpdate = true;
             previousScore = existingRating.score;
         }
         // --- End Simplified ---


        // Update overall rating sum and count for the entity owner
        if (isUpdate) {
            userRatingSum[entityOwner] = userRatingSum[entityOwner].sub(previousScore).add(score);
        } else {
            userRatingSum[entityOwner] = userRatingSum[entityOwner].add(score);
            userRatingCount[entityOwner] = userRatingCount[entityOwner].add(1);
             // Add rater to list (costly check)
            // ...
        }

        // Create/Update rating record
        UserRating storage rating = userRatings[msg.sender][entityOwner]; // Overwrites previous if keying only by rater->ratedUser
        // Use the dedicated mapping if implemented: UserRating storage rating = entityRatings[msg.sender][entityId];
        rating.rater = msg.sender;
        rating.ratedUser = entityOwner;
        rating.timestamp = block.timestamp;
        rating.score = score;
        rating.comment = comment;
        rating.entityId = entityId;
        rating.category = category;

        // Update entity owner's reputation based on score change (less impact than direct user rating?)
        int256 reputationChange = 0;
        if (score >= 4) reputationChange = 3; // Good rating
        else if (score <= 2) reputationChange = -3; // Bad rating
        // Neutral rating (3) gives no change

        if (reputationChange > 0) {
            userReputation[entityOwner] = userReputation[entityOwner].add(uint256(reputationChange));
        } else if (reputationChange < 0) {
             if (userReputation[entityOwner] >= uint256(-reputationChange)) {
                userReputation[entityOwner] = userReputation[entityOwner].sub(uint256(-reputationChange));
            } else {
                 userReputation[entityOwner] = 0;
            }
        }


        // Notify the entity owner
        bytes32 entityIdNotify = keccak256(abi.encodePacked("rating", msg.sender, entityId));
         createNotification(
            entityOwner,
            "ENTITY_RATED",
            entityIdNotify,
            string(abi.encodePacked("Your entity (", uint256(entityId).toString() ,") was rated ", uint256(score).toString(), " stars"))
         );


        emit UserRated(msg.sender, entityOwner, score, entityId, category);
    }

    // Get rating details given by a specific rater to a specific rated user (latest direct rating)
    function getUserRatingDetails(address rater, address ratedUser)
        external
        view
        returns (
            uint256 timestamp,
            uint8 score,
            string memory comment,
            bytes32 entityId, // Will be 0 for direct user rating
            RatingCategory category
        )
    {
        UserRating storage rating = userRatings[rater][ratedUser];
         // Only returns the last rating stored under this key pair
        return (
            rating.timestamp,
            rating.score,
            rating.comment,
            rating.entityId,
            rating.category
        );
    }

    // Get the average rating and count for a specific user
    function getUserAverageRating(address user)
        external
        view
        returns (uint256 averageRating, uint256 ratingCount) // Returns average score * 100 (e.g., 450 for 4.5 stars)
    {
        ratingCount = userRatingCount[user];
        if (ratingCount > 0) {
            averageRating = userRatingSum[user].mul(100).div(ratingCount); // Scale to 100 for two decimal places
        } else {
            averageRating = 0;
        }
        return (averageRating, ratingCount);
    }

    // Get list of users who have rated a specific user (might become very large)
    // function getUserRaters(address user)
    //     external
    //     view
    //     returns (address[] memory)
    // {
    //     // This is potentially unbounded and gas-intensive. Consider off-chain indexing.
    //     // return userRaters[user];
    //      revert("Fetching all raters is too gas intensive. Use off-chain indexing.");
    // }

    // Structure for user feedback
    struct UserFeedback {
        uint256 id; // Global unique ID
        address user;
        string feedbackType; // e.g., "Bug Report", "Suggestion", "Complaint"
        string content;
        uint256 timestamp;
        bool isAddressed;
        uint256 addressedTimestamp;
        address addressedBy; // Who addressed it (owner/admin)
        string response; // Optional response from admin
    }


    // Event for user feedback
    event FeedbackSubmitted(uint256 indexed feedbackId, address indexed user, string feedbackType);
    event FeedbackAddressed(uint256 indexed feedbackId, address indexed addressedBy);

// Internal function for parameter setting (แยกออกมา)
function _setDatasetParameters(
    Dataset storage newDataset, // Pass by storage reference
    uint256 _paramSize,
    string memory _paramFormat,
    uint256 _paramVersion,
    string memory _paramLicense,
    string[] memory _paramContributors,
    uint256 _paramUpdateFrequency,
    bool _paramIsVerified
) internal {
    newDataset.parameters.size = _paramSize;
    newDataset.parameters.format = _paramFormat;
    newDataset.parameters.version = _paramVersion;
    newDataset.parameters.license = _paramLicense;
    delete newDataset.parameters.contributors; // Clear first if needed
    for(uint i=0; i<_paramContributors.length; i++) {
         newDataset.parameters.contributors.push(_paramContributors[i]);
    }
    newDataset.parameters.updateFrequency = _paramUpdateFrequency;
    newDataset.parameters.isVerified = _paramIsVerified;
}

// Internal function for tag processing (แยกออกมา)
function _processDatasetTags(Dataset storage newDataset, string[] memory _tags) internal {
    delete newDataset.tags; // Clear first
    for (uint256 i = 0; i < _tags.length; i++) {
        // ควรมี check ความยาว tag ด้วยถ้าจำเป็น
        newDataset.tags.push(_tags[i]);
    }
}

// Internal function for ownership/access and fee (แยกออกมา)
function _finalizeDatasetCreation(uint256 newDatasetId) internal {
     // Add ownership and access
     ownedDatasets[msg.sender].add(newDatasetId);
     datasetAccess[newDatasetId][msg.sender] = true;

     // Fee processing
     uint256 platformFeeAmount = 0.01 ether;
     require(userBalances[msg.sender] >= platformFeeAmount, "Insufficient balance for platform fee");
     userBalances[msg.sender] = userBalances[msg.sender].sub(platformFeeAmount);
     userBalances[feeCollector] = userBalances[feeCollector].add(platformFeeAmount);
     emit FeePaid(msg.sender, platformFeeAmount, "Dataset Creation");
}

// }