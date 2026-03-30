// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateRevenueDistributor {
    function depositRevenue(address property, uint256 amount) external;
    function updateOnTransfer(address property, address from, address to) external;
    function claim(address property) external;
    function pendingRevenue(address property, address user) external view returns (uint256);
}