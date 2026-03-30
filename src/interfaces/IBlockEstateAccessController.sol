// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateAccessController {
    function enforceAdmin(address account) external view;
    function enforceFundsManager(address account) external view;
    function isKYCApproved(address user) external view returns (bool);
    function isBlacklisted(address user) external view returns (bool);
    function isProtocolPaused() external view returns (bool);
    function owner() external view returns (address);
}