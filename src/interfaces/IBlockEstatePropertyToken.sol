// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstatePropertyToken {
    function mint(address to, uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function factory() external view returns (address);
    function assetOwner() external view returns (address);
}