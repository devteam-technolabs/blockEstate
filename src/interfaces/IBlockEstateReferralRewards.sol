// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateReferralRewards {
    function registerReward(address user, uint256 amount) external;
}