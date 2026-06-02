// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateRevenueDistributor {
    function depositRevenue(address property, uint256 amount) external;
    function updateOnTransfer(address property, address from, address to) external;
    function claim(address property) external;
    function pendingRevenue(address property, address user) external view returns (uint256);

    // New functions for per-property accounting
    function propertyEscrow(address property) external view returns (uint256);
    function accRevenuePerToken(address property) external view returns (uint256);
    function rewardDebt(address property, address user) external view returns (uint256);
    function pending(address property, address user) external view returns (uint256);
    function leftover(address property) external view returns (uint256);
    function getPropertyEscrow(address property) external view returns (uint256);

    // Constants
    function ACCURACY() external view returns (uint256);
}
