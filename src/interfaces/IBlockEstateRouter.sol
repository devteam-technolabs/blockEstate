// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateRouter {

    function confirmAccessControllerUpdate() external;

    function getAccessController() external view returns (address);
}