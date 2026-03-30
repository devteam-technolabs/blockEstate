// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateRouter {
    function accessController() external view returns (address);
    function factory() external view returns (address);
    function treasury() external view returns (address);
    function stableToken() external view returns (address);
    function revenueDistributor() external view returns (address);
    function referralRewards() external view returns (address);
    function assetIssuance() external view returns (address);
    function confirmAccessControllerUpdate() external;
}