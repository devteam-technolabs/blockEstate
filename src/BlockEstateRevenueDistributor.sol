// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./BlockEstateRouter.sol";
import "./BlockEstatePropertyToken.sol";
import "./interfaces/IBlockEstateAccessController.sol";

contract BlockEstateRevenueDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    BlockEstateRouter public router;

    uint256 public constant ACCURACY = 1e18;

    // property => accumulated revenue per token
    mapping(address => uint256) public accRevenuePerToken;

    // property => user => reward debt
    mapping(address => mapping(address => uint256)) public rewardDebt;

    // property => user => pending rewards
    mapping(address => mapping(address => uint256)) public pending;

    mapping(address => uint256) public leftover;

    event RevenueDeposited(address indexed property, uint256 amount);
    event Claimed(address indexed user, address indexed property, uint256 amount);

    event DustCarried(address indexed property, uint256 amount);

    constructor(address router_) {
        router = BlockEstateRouter(router_);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyPropertyOwner(address property) {
        require(
            msg.sender == BlockEstatePropertyToken(property).assetOwner(),
            "NOT_PROPERTY_OWNER"
        );
        _;
    }

    modifier onlyCompliant(address user) {
        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT REVENUE
    //////////////////////////////////////////////////////////////*/

    function depositRevenue(address property, uint256 amount)
        external
        nonReentrant
        onlyPropertyOwner(property)
    {
        require(amount > 0, "INVALID_AMOUNT");
        require(
            BlockEstatePropertyToken(property).factory() == router.factory(),
            "INVALID_PROPERTY"
        );

        IERC20 stable = IERC20(router.stableToken());

        // transfer funds
        stable.safeTransferFrom(msg.sender, address(this), amount);

        uint256 supply = BlockEstatePropertyToken(property).totalSupply();
        require(supply > 0, "NO_SUPPLY");

        uint256 total = amount + leftover[property];

        uint256 increment = (total * ACCURACY) / supply;

        uint256 distributed = (increment * supply) / ACCURACY;
        leftover[property] = total - distributed;

        accRevenuePerToken[property] += increment;

        emit RevenueDeposited(property, amount);

        if (leftover[property] > 0) {
            emit DustCarried(property, leftover[property]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE USER (CORE LOGIC)
    //////////////////////////////////////////////////////////////*/

    function _updateUser(address property, address user) internal {
        uint256 balance = BlockEstatePropertyToken(property).balanceOf(user);

        uint256 accumulated =
            (balance * accRevenuePerToken[property]) / ACCURACY;

        uint256 debt = rewardDebt[property][user];

        uint256 pendingAmount = accumulated - debt;

        if (pendingAmount > 0) {
            pending[property][user] += pendingAmount;
        }

        rewardDebt[property][user] = accumulated;
    }

    /*//////////////////////////////////////////////////////////////
                        CALLED BY TOKEN (CRITICAL)
    //////////////////////////////////////////////////////////////*/

    function updateOnTransfer(
        address property,
        address from,
        address to
    ) external {
        require(msg.sender == property, "ONLY_PROPERTY_TOKEN");
        require(
            BlockEstatePropertyToken(property).factory() == router.factory(),
            "INVALID_PROPERTY"
        );

        if (from != address(0)) {
            _updateUser(property, from);
        }

        if (to != address(0)) {
            _updateUser(property, to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM
    //////////////////////////////////////////////////////////////*/

    function claim(address property)
        external
        nonReentrant
        onlyCompliant(msg.sender)
    {
        _updateUser(property, msg.sender);

        uint256 amount = pending[property][msg.sender];
        require(amount > 0, "NO_REWARD");

        pending[property][msg.sender] = 0;

        IERC20(router.stableToken()).safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, property, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/

    function pendingRevenue(address property, address user)
        external
        view
        returns (uint256)
    {
        uint256 balance = BlockEstatePropertyToken(property).balanceOf(user);

        uint256 accumulated =
            (balance * accRevenuePerToken[property]) / ACCURACY;

        uint256 debt = rewardDebt[property][user];

        return pending[property][user] + (accumulated - debt);
    }
}