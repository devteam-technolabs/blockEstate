// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../BlockEstateRouter.sol";
import "../interfaces/IBlockEstateAccessController.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BlockEstateReferralRewards is ReentrancyGuard {

    using SafeERC20 for IERC20;
    BlockEstateRouter public router;

    mapping(address => address) public referrerOf;
    mapping(address => uint256) public rewards;

    event ReferralSet(address user, address referrer);
    event RewardAdded(address referrer, uint256 amount);
    event Claimed(address user, uint256 amount);

    constructor(address router_) {
        router = BlockEstateRouter(router_);
    }

    modifier onlyFactory() {
        require(msg.sender == router.factory(), "NOT_FACTORY");
        _;
    }

    modifier onlyCompliant(address user) {
        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isBlacklisted(user), "BLACKLISTED");
        require(ac.isKYCApproved(user), "KYC_REQUIRED");
        _;
    }

    function setReferrer(address referrer)
        external
        onlyCompliant(msg.sender)
    {
        require(referrer != msg.sender, "SELF");
        require(referrerOf[msg.sender] == address(0), "EXISTS");

        referrerOf[msg.sender] = referrer;
        emit ReferralSet(msg.sender, referrer);
    }

    function registerReward(address user, uint256 amount)
        external
        onlyFactory
    {
        address ref = referrerOf[user];
        if (ref != address(0)) {
            rewards[ref] += amount;
            emit RewardAdded(ref, amount);
        }
    }

    function claim() external nonReentrant {
        require(router.stableToken() != address(0), "NO_STABLE");
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "NO_REWARD");

        rewards[msg.sender] = 0;
        IERC20(router.stableToken()).safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }
}