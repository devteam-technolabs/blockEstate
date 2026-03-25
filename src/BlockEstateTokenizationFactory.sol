// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BlockEstateRouter} from "./BlockEstateRouter.sol";
import {BlockEstatePropertyToken} from "./BlockEstatePropertyToken.sol";
import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IBlockEstateReferralRewards} from "./interfaces/IBlockEstateReferralRewards.sol";

/**
 * @title BlockEstateTokenizationFactory
 * @dev Handles property deployment and investments (on-chain + fiat).
 */
contract BlockEstateTokenizationFactory is ReentrancyGuard {

    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    address public backendSigner;

    BlockEstateRouter public router;
    uint256 public platformFeeBps = 500; // 5%
   
    address[] public properties;

    mapping(address => bool) public isValidProperty;
    mapping(bytes32 => bool) public processedPayments;
   
    event PropertyCreated(address indexed property);
    event Invested(address indexed user, address indexed property, uint256 amount);
    event FiatProcessed(address indexed user, uint256 amount, bytes32 paymentId);

    constructor(address router_) {
        router = BlockEstateRouter(router_);
    }

    modifier onlyCompliant(address user) {
        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");
        require(!ac.isProtocolPaused(), "PAUSED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PROPERTY CREATION
    //////////////////////////////////////////////////////////////*/

    function createProperty(
        string memory name,
        string memory symbol,
        address admin,
        address owner
    ) external returns (address) {

        IBlockEstateAccessController(router.accessController())
            .enforceAdmin(msg.sender);

        address property = address(
            new BlockEstatePropertyToken(
                address(router),
                address(this),
                name,
                symbol,
                admin,
                owner
            )
        );

        properties.push(property);
        isValidProperty[property] = true;

        emit PropertyCreated(property);
        return property;
    }

    /*//////////////////////////////////////////////////////////////
                        INVEST (ON-CHAIN)
    //////////////////////////////////////////////////////////////*/

    function invest(address property, uint256 amount)
        external
        nonReentrant
        onlyCompliant(msg.sender)
    {
        require(amount > 0, "INVALID_AMOUNT");
        require(isValidProperty[property], "INVALID_PROPERTY");
        require(router.stableToken() != address(0), "INVALID_STABLE_TOKEN");
        require(router.treasury() != address(0), "INVALID_TREASURY");

        IERC20 stable = IERC20(router.stableToken());

        uint256 fee = (amount * platformFeeBps) / 10_000;
        uint256 net = amount - fee;

        stable.safeTransferFrom(msg.sender, address(this), amount);

        if (net > 0) {
            stable.safeTransfer(router.treasury(), net);
        }

        address referralPool = router.referralRewards();

        if (fee > 0 && referralPool != address(0)) {
            stable.safeTransfer(referralPool, fee);
        }

        BlockEstatePropertyToken(property).mint(msg.sender, net);

        if (referralPool != address(0)) {
            IBlockEstateReferralRewards(referralPool).registerReward(msg.sender, net);
        }

        emit Invested(msg.sender, property, net);
    }

    /*//////////////////////////////////////////////////////////////
                        INVEST (FIAT)
    //////////////////////////////////////////////////////////////*/
   
    function processFiatInvestment(
        address user,
        address property,
        uint256 amount,
        bytes32 paymentId,
        bytes calldata signature
    ) external nonReentrant {
        require(router.stableToken() != address(0), "INVALID_STABLE_TOKEN");
        require(user != address(0), "INVALID_USER");
        require(amount > 0, "INVALID_AMOUNT");
        require(isValidProperty[property], "INVALID_PROPERTY");
        require(!processedPayments[paymentId], "ALREADY_PROCESSED");

        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");

        bytes32 hash = keccak256(
            abi.encode(
                user,
                property,
                amount,
                paymentId,
                address(this),
                block.chainid
            )
        );

        bytes32 digest = hash.toEthSignedMessageHash();
        address signer = ECDSA.recover(digest, signature);

        require(signer == backendSigner, "INVALID_SIGNATURE");

        // prevent replay
        processedPayments[paymentId] = true;

        uint256 fee = (amount * platformFeeBps) / 10_000;
        uint256 net = amount - fee;

        address referralPool = router.referralRewards();

        BlockEstatePropertyToken(property).mint(user, net);

        if (referralPool != address(0) && fee > 0) {
            IBlockEstateReferralRewards(referralPool).registerReward(user, net);
        }

        emit FiatProcessed(user, net, paymentId);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function setBackendSigner(address signer) external {
        IBlockEstateAccessController(router.accessController())
            .enforceAdmin(msg.sender);

        require(signer != address(0), "INVALID_SIGNER");
        backendSigner = signer;
    }

    function totalProperties() external view returns (uint256) {
        return properties.length;
    }
}