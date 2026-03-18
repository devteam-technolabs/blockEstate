// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateReferralRewards {

    function referralStats(address user)
        external
        view
        returns (
            uint256 totalReferrals,
            uint256 propertyRewards,
            uint256 globalRewards
        );

    function registerPropertyReward(
        address beneficiary,
        address referrer,
        uint256 purchaseValue,
        uint256 propertyId
    ) external;

    function registerGlobalReward(
        address beneficiary,
        uint256 rewardAmount
    ) external;

    function claimPropertyReward(
        address user,
        uint256 propertyId
    ) external;

    function claimGlobalReward(address user) external;
}