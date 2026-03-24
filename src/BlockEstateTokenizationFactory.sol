// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BlockEstateRouter.sol";
import "./BlockEstatePropertyToken.sol";
import "./interfaces/IBlockEstateAccessController.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BlockEstateTokenizationFactory is ReentrancyGuard {

    using SafeERC20 for IERC20;

    BlockEstateRouter public router;
    address public authorizedGateway;

    address[] public properties;

    mapping(address => bool) public isValidProperty;

    event PropertyCreated(address indexed property);
    event Invested(address indexed user, address indexed property, uint256 amount);

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

        // ✅ Mark as valid
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

        // ✅ CRITICAL FIX
        require(isValidProperty[property], "INVALID_PROPERTY");

        require(router.stableToken() != address(0), "INVALID_STABLE_TOKEN");
        require(router.treasury() != address(0), "INVALID_TREASURY");

        IERC20 stable = IERC20(router.stableToken());

        // transfer USDC → treasury
        stable.safeTransferFrom(msg.sender, router.treasury(), amount);

        // mint shares
        BlockEstatePropertyToken(property).mint(msg.sender, amount);

        emit Invested(msg.sender, property, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INVEST (FIAT)
    //////////////////////////////////////////////////////////////*/

    function investFromFiat(
        address property,
        address user,
        uint256 amount
    ) external {

        require(msg.sender == authorizedGateway, "NOT_GATEWAY");
        require(user != address(0), "INVALID_USER");
        require(amount > 0, "INVALID_AMOUNT");

        // ✅ CRITICAL FIX HERE TOO
        require(isValidProperty[property], "INVALID_PROPERTY");

        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");

        BlockEstatePropertyToken(property).mint(user, amount);

        emit Invested(user, property, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN
    //////////////////////////////////////////////////////////////*/

    function setAuthorizedGateway(address gateway) external {
        IBlockEstateAccessController(router.accessController())
            .enforceAdmin(msg.sender);

        authorizedGateway = gateway;
    }

    function totalProperties() external view returns (uint256) {
        return properties.length;
    }
}