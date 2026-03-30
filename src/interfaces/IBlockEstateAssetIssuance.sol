// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateAssetIssuance {
    function createPropertyToken(
        string memory name,
        string memory symbol,
        address admin,
        address owner
    ) external returns (address);
}