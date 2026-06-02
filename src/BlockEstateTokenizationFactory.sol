// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BlockEstateRouter} from "./BlockEstateRouter.sol";
import {BlockEstatePropertyToken} from "./BlockEstatePropertyToken.sol";
import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {IBlockEstateAssetIssuance} from "./interfaces/IBlockEstateAssetIssuance.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IBlockEstateReferralRewards} from "./interfaces/IBlockEstateReferralRewards.sol";
import {BlockEstateConfig} from "./BlockEstateConfig.sol";

/**
 * @title BlockEstateTokenizationFactory
 * @dev Handles property deployment and investments (on-chain + fiat).
 */
contract BlockEstateTokenizationFactory is ReentrancyGuard, BlockEstateConfig {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    BlockEstateRouter public router;
    uint256 public platformFeeBps = 500; // 5%

    address[] public properties;

    mapping(address => bool) public isValidProperty;
    mapping(bytes32 => bool) public processedPayments;

    // Property metadata - status removed (read from token directly)
    struct PropertyInfo {
        string name;
        string symbol;
        uint256 valuation;
        uint256 targetRaise;
        uint256 totalShares;
        uint256 sharesSold;
        bool fundraisingClosed;
        address propertyOwner;
        uint256 sharePrice;
        uint256 maxSupply;
        // status removed - read from token
    }

    mapping(address => PropertyInfo) public propertyInfo;

    event PropertyCreated(address indexed property, string name, string symbol, uint256 maxSupply, uint256 sharePrice);
    event Invested(address indexed user, address indexed property, uint256 amount, uint256 shares);
    event FiatProcessed(address indexed user, uint256 amount, bytes32 paymentId);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    constructor(address router_) {
        require(router_ != address(0), "INVALID_ROUTER");
        router = BlockEstateRouter(router_);
    }

    modifier onlyCompliant(address user) {
        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");
        require(!ac.isProtocolPaused(), "PAUSED");
        _;
    }

    modifier onlyBackendSigner() {
        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());
        require(ac.isBackendSigner(msg.sender), "NOT_BACKEND_SIGNER");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PROPERTY CREATION
    //////////////////////////////////////////////////////////////*/

    function createProperty(
        string memory name,
        string memory symbol,
        address admin,
        address owner,
        uint256 maxSupply,
        uint256 sharePrice,
        uint256 valuation,
        uint256 targetRaise
    ) external returns (address) {
        IBlockEstateAccessController(router.accessController()).enforceAdmin(msg.sender);

        require(admin != address(0), "INVALID_ADMIN");
        require(owner != address(0), "INVALID_OWNER");
        require(maxSupply > 0, "INVALID_MAX_SUPPLY");
        require(sharePrice > 0, "INVALID_SHARE_PRICE");
        require(valuation > 0, "INVALID_VALUATION");
        require(targetRaise > 0, "INVALID_TARGET_RAISE");

        // Validate that target raise matches supply × share price
        uint256 expectedTargetRaise = (maxSupply * sharePrice) / 1e18;
        require(targetRaise == expectedTargetRaise, "TARGET_RAISE_MISMATCH");

        require(valuation >= targetRaise, "VALUATION_TOO_LOW");

        address assetIssuance = router.assetIssuance();
        require(assetIssuance != address(0), "ASSET_ISSUANCE_NOT_SET");

        address property = IBlockEstateAssetIssuance(assetIssuance)
            .createPropertyToken(name, symbol, admin, owner, maxSupply, sharePrice);

        properties.push(property);
        isValidProperty[property] = true;

        propertyInfo[property] = PropertyInfo({
            name: name,
            symbol: symbol,
            valuation: valuation,
            targetRaise: targetRaise,
            totalShares: maxSupply,
            sharesSold: 0,
            fundraisingClosed: false,
            propertyOwner: owner,
            sharePrice: sharePrice,
            maxSupply: maxSupply
        });

        emit PropertyCreated(property, name, symbol, maxSupply, sharePrice);
        return property;
    }

    /*//////////////////////////////////////////////////////////////
                        INVEST (ON-CHAIN)
    //////////////////////////////////////////////////////////////*/

    function invest(address property, uint256 amount) external nonReentrant onlyCompliant(msg.sender) {
        require(amount > 0, "INVALID_AMOUNT");
        require(isValidProperty[property], "INVALID_PROPERTY");

        PropertyInfo storage info = propertyInfo[property];
        require(!info.fundraisingClosed, "FUNDRAISING_CLOSED");

        // Read status directly from token - SINGLE SOURCE OF TRUTH
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        require(token.status() == BlockEstateConfig.PropertyStatus.FUNDRAISING, "NOT_FUNDRAISING");

        address stableTokenAddr = router.stableToken();
        address treasuryAddr = router.treasury();

        require(stableTokenAddr != address(0), "INVALID_STABLE_TOKEN");
        require(treasuryAddr != address(0), "INVALID_TREASURY");

        IERC20 stable = IERC20(stableTokenAddr);

        uint256 fee = (amount * platformFeeBps) / BPS;
        uint256 net = amount - fee;

        // Calculate shares based on share price
        uint256 shares = token.calculateShares(net);
        require(shares > 0, "SHARES_TOO_LOW");
        require(info.sharesSold + shares <= info.maxSupply, "MAX_SUPPLY_EXCEEDED");

        stable.safeTransferFrom(msg.sender, address(this), amount);

        if (net > 0) {
            stable.safeTransfer(treasuryAddr, net);
        }

        address referralPool = router.referralRewards();

        if (fee > 0 && referralPool != address(0)) {
            stable.safeTransfer(referralPool, fee);
        }

        // Mint using the new mint function that takes stable amount
        uint256 actualShares = token.mint(msg.sender, net);

        // Update property info
        info.sharesSold += actualShares;
        if (info.sharesSold >= info.maxSupply) {
            info.fundraisingClosed = true;
            token.closeFundraising();
        }

        if (referralPool != address(0)) {
            IBlockEstateReferralRewards(referralPool).registerReward(msg.sender, net);
        }

        emit Invested(msg.sender, property, net, actualShares);
    }

    /*//////////////////////////////////////////////////////////////
                        INVEST (FIAT) - SIMPLIFIED
    //////////////////////////////////////////////////////////////*/

    function processFiatInvestment(address user, address property, uint256 amount, bytes32 paymentId, uint256 deadline)
        external
        nonReentrant
        onlyBackendSigner
    {
        require(block.timestamp <= deadline, "EXPIRED");
        require(router.stableToken() != address(0), "INVALID_STABLE_TOKEN");
        require(user != address(0), "INVALID_USER");
        require(amount > 0, "INVALID_AMOUNT");
        require(isValidProperty[property], "INVALID_PROPERTY");
        require(!processedPayments[paymentId], "ALREADY_PROCESSED");

        PropertyInfo storage info = propertyInfo[property];
        require(!info.fundraisingClosed, "FUNDRAISING_CLOSED");

        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());

        require(!ac.isProtocolPaused(), "PROTOCOL_PAUSED");
        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");

        processedPayments[paymentId] = true;

        uint256 fee = (amount * platformFeeBps) / BPS;
        uint256 net = amount - fee;

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 shares = token.calculateShares(net);
        require(shares > 0, "SHARES_TOO_LOW");
        require(info.sharesSold + shares <= info.maxSupply, "MAX_SUPPLY_EXCEEDED");

        address referralPool = router.referralRewards();

        uint256 actualShares = token.mint(user, net);

        info.sharesSold += actualShares;
        if (info.sharesSold >= info.maxSupply) {
            info.fundraisingClosed = true;
            token.closeFundraising();
        }

        if (referralPool != address(0) && fee > 0) {
            IBlockEstateReferralRewards(referralPool).registerReward(user, net);
        }

        emit FiatProcessed(user, net, paymentId);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function setPlatformFeeBps(uint256 newFeeBps) external {
        IBlockEstateAccessController(router.accessController()).enforceAdmin(msg.sender);

        require(newFeeBps <= MAX_PLATFORM_FEE, "FEE_TOO_HIGH");

        uint256 oldFee = platformFeeBps;
        platformFeeBps = newFeeBps;

        emit PlatformFeeUpdated(oldFee, newFeeBps);
    }

    function emergencyWithdrawERC20(address token, address to, uint256 amount) external {
        IBlockEstateAccessController(router.accessController()).enforceAdmin(msg.sender);

        require(token != address(0), "INVALID_TOKEN");
        require(to != address(0), "INVALID_ADDRESS");
        require(amount > 0, "INVALID_AMOUNT");

        // Prevent withdrawal of the protocol's stable token
        require(token != router.stableToken(), "CANNOT_WITHDRAW_STABLE_TOKEN");

        IERC20(token).safeTransfer(to, amount);
        emit EmergencyWithdraw(token, to, amount);
    }

    function getPropertyInfo(address property) external view returns (PropertyInfo memory) {
        return propertyInfo[property];
    }

    function totalProperties() external view returns (uint256) {
        return properties.length;
    }
}
