// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../BlockEstateRouter.sol";
import "../interfaces/IBlockEstateAccessController.sol";

/**
 * @title BlockEstateReferralRewards
 * @dev Tracks and distributes referral rewards.
 */
contract BlockEstateReferralRewards is ReentrancyGuard {
    using SafeERC20 for IERC20;

    BlockEstateRouter public router;

    mapping(address => address) public referrerOf;
    mapping(address => uint256) public rewards;

    uint256 public referralBps = 500;
    uint256 public constant BPS = 10_000;

    event ReferralSet(address indexed user, address indexed referrer);
    event RewardAdded(address indexed referrer, address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event ReferralBpsUpdated(uint256 newBps);

    constructor(address router_) {
        router = BlockEstateRouter(router_);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyFactory() {
        require(msg.sender == router.factory(), "NOT_FACTORY");
        _;
    }

    modifier onlyAdmin() {
        IBlockEstateAccessController(router.accessController())
            .enforceAdmin(msg.sender);
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
                            REFERRAL SETUP
    //////////////////////////////////////////////////////////////*/

    function setReferrer(address referrer)
        external
        onlyCompliant(msg.sender)
    {
        require(referrer != address(0), "INVALID_REFERRER");
        require(referrer != msg.sender, "SELF_REFERRAL");
        require(referrerOf[msg.sender] == address(0), "ALREADY_SET");

        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(ac.isKYCApproved(referrer), "REFERRER_NOT_KYC");

        referrerOf[msg.sender] = referrer;

        emit ReferralSet(msg.sender, referrer);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function registerReward(address user, uint256 investmentAmount)
        external
        onlyFactory
    {
        address ref = referrerOf[user];
        if (ref == address(0)) return;

        uint256 reward = (investmentAmount * referralBps) / BPS;
        if (reward == 0) return;

        rewards[ref] += reward;

        emit RewardAdded(ref, user, reward);
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/

    function claim()
        external
        nonReentrant
        onlyCompliant(msg.sender)
    {
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "NO_REWARD");

        uint256 balance = IERC20(router.stableToken()).balanceOf(address(this));
        require(balance >= amount, "INSUFFICIENT_FUNDS");

        rewards[msg.sender] = 0;

        IERC20(router.stableToken()).safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function setReferralBps(uint256 newBps) external onlyAdmin {
        require(newBps <= 2000, "TOO_HIGH");
        referralBps = newBps;

        emit ReferralBpsUpdated(newBps);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function pendingReward(address user) external view returns (uint256) {
        return rewards[user];
    }
}