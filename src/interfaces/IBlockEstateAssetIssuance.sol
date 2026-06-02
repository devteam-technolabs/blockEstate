// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateAssetIssuance {
    function createPropertyToken(
        string memory name,
        string memory symbol,
        address admin,
        address owner,
        uint256 maxSupply,
        uint256 sharePrice
    ) external returns (address);

    function factory() external view returns (address);
    function router() external view returns (address);
}
