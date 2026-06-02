// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateRouter {
    // View functions
    function accessController() external view returns (address);
    function factory() external view returns (address);
    function treasury() external view returns (address);
    function stableToken() external view returns (address);
    function revenueDistributor() external view returns (address);
    function referralRewards() external view returns (address);
    function assetIssuance() external view returns (address);
    function confirmAccessControllerUpdate() external;
    function getAccessController() external view returns (address);

    // New timelock functions
    function executeSetFactory(address _factory) external;
    function executeSetTreasury(address _treasury) external;
    function executeSetStableToken(address _token) external;
    function executeSetRevenueDistributor(address _addr) external;
    function executeSetReferralRewards(address _addr) external;
    function executeSetAssetIssuance(address _addr) external;
    function cancelPendingChange(string memory key) external;

    // New struct access (if needed for frontend)
    function pendingChanges(bytes32 changeId) external view returns (address target, uint64 timestamp, bool exists);
}
