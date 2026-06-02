// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BlockEstateConfig} from "../BlockEstateConfig.sol";

interface IBlockEstatePropertyToken {
    function mint(address to, uint256 stableAmount) external returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function factory() external view returns (address);
    function assetOwner() external view returns (address);
    function admin() external view returns (address);
    function router() external view returns (address);

    // New property metadata functions
    function maxSupply() external view returns (uint256);
    function sharePrice() external view returns (uint256);
    function totalRaised() external view returns (uint256);
    function fundraisingClosed() external view returns (bool);
    function status() external view returns (BlockEstateConfig.PropertyStatus);

    // New functionality
    function calculateShares(uint256 stableAmount) external view returns (uint256);
    function closeFundraising() external;
    function updateStatus(BlockEstateConfig.PropertyStatus newStatus) external;
    function pauseProperty() external;
    function unpauseProperty() external;
}
