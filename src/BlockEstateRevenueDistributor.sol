// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BlockEstateRouter} from "./BlockEstateRouter.sol";
import {BlockEstatePropertyToken} from "./BlockEstatePropertyToken.sol";
import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {IBlockEstatePropertyToken} from "./interfaces/IBlockEstatePropertyToken.sol";

contract BlockEstateRevenueDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    BlockEstateRouter public router;
    uint256 public constant ACCURACY = 1e18;

    mapping(address => uint256) public accRevenuePerToken;
    mapping(address => mapping(address => uint256)) public rewardDebt;
    mapping(address => mapping(address => uint256)) public pending;
    mapping(address => uint256) public leftover;
    mapping(address => uint256) public propertyEscrow;

    event RevenueDeposited(address indexed property, uint256 amount);
    event Claimed(address indexed user, address indexed property, uint256 amount);
    event DustCarried(address indexed property, uint256 amount);

    constructor(address router_) {
        router = BlockEstateRouter(router_);
    }

    modifier onlyPropertyOwner(address property) {
        require(msg.sender == BlockEstatePropertyToken(property).assetOwner(), "NOT_PROPERTY_OWNER");
        _;
    }

    modifier onlyCompliant(address user) {
        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());
        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");
        _;
    }

    modifier onlyCompliantPropertyOwner(address property) {
        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());
        address owner = BlockEstatePropertyToken(property).assetOwner();
        require(msg.sender == owner, "NOT_PROPERTY_OWNER");
        require(!ac.isProtocolPaused(), "PROTOCOL_PAUSED");
        require(!ac.isBlacklisted(owner), "OWNER_BLACKLISTED");
        require(ac.isKYCApproved(owner), "OWNER_NOT_KYC");
        _;
    }

    function depositRevenue(address property, uint256 amount)
        external
        nonReentrant
        onlyCompliantPropertyOwner(property)
    {
        require(amount > 0, "INVALID_AMOUNT");
        require(IBlockEstatePropertyToken(property).factory() == router.factory(), "INVALID_PROPERTY");

        IERC20 stable = IERC20(router.stableToken());
        stable.safeTransferFrom(msg.sender, address(this), amount);

        propertyEscrow[property] += amount;

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

    function _updateUserWithBalance(address property, address user, uint256 balance) internal {
        uint256 accumulated = (balance * accRevenuePerToken[property]) / ACCURACY;
        uint256 debt = rewardDebt[property][user];

        if (accumulated > debt) {
            uint256 pendingAmount = accumulated - debt;
            if (pendingAmount > 0) {
                pending[property][user] += pendingAmount;
            }
        }

        rewardDebt[property][user] = accumulated;
    }

    function _setUserDebt(address property, address user, uint256 balance) internal {
        rewardDebt[property][user] = (balance * accRevenuePerToken[property]) / ACCURACY;
    }

    function _updateUser(address property, address user) internal {
        uint256 balance = BlockEstatePropertyToken(property).balanceOf(user);
        _updateUserWithBalance(property, user, balance);
    }

    function updateOnTransfer(
        address property,
        address from,
        address to,
        uint256 amount,
        uint256 fromBalanceBefore,
        uint256 toBalanceBefore,
        uint256 fromBalanceAfter,
        uint256 toBalanceAfter
    ) external {
        require(msg.sender == property, "ONLY_PROPERTY_TOKEN");
        require(IBlockEstatePropertyToken(property).factory() == router.factory(), "INVALID_PROPERTY");

        // Settle rewards for sender using their balance BEFORE transfer
        if (from != address(0)) {
            _updateUserWithBalance(property, from, fromBalanceBefore);
        }

        // Settle rewards for recipient using their balance BEFORE transfer
        if (to != address(0)) {
            _updateUserWithBalance(property, to, toBalanceBefore);
        }

        // CRITICAL: Reset reward debt to post-transfer balances to prevent double-counting
        if (from != address(0)) {
            _setUserDebt(property, from, fromBalanceAfter);
        }

        if (to != address(0)) {
            _setUserDebt(property, to, toBalanceAfter);
        }
    }

    function claim(address property) external nonReentrant onlyCompliant(msg.sender) {
        require(IBlockEstatePropertyToken(property).factory() == router.factory(), "INVALID_PROPERTY");

        _updateUser(property, msg.sender);

        uint256 amount = pending[property][msg.sender];
        require(amount > 0, "NO_REWARD");
        require(propertyEscrow[property] >= amount, "INSUFFICIENT_PROPERTY_FUNDS");

        pending[property][msg.sender] = 0;
        propertyEscrow[property] -= amount;

        IERC20(router.stableToken()).safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, property, amount);
    }

    function pendingRevenue(address property, address user) external view returns (uint256) {
        uint256 balance = BlockEstatePropertyToken(property).balanceOf(user);
        uint256 accumulated = (balance * accRevenuePerToken[property]) / ACCURACY;
        uint256 debt = rewardDebt[property][user];

        uint256 pendingAmount = 0;
        if (accumulated > debt) {
            pendingAmount = accumulated - debt;
        }

        return pending[property][user] + pendingAmount;
    }

    function getPropertyEscrow(address property) external view returns (uint256) {
        return propertyEscrow[property];
    }
}
