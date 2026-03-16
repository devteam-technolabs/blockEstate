// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Access Controller Interface
 * @author devItechnolabs
 *
 * @notice
 * Provides a unified access verification layer
 * used across BlockEstate protocol modules.
 */
interface IBlockEstateAccessController {

    /// Returns the primary protocol administrator
    function protocolOwner() external view returns (address);

    /// Verifies whether an address has admin privileges
    function requireAdmin(address account) external view;

    /// Verifies treasury/funds management privileges
    function requireTreasuryOperator(address account) external view;

    /// Returns true if user completed compliance verification
    function isVerifiedInvestor(address user) external view returns (bool);

    /// Returns protocol operational state
    function isSystemPaused() external view returns (bool);

    /// Returns whether an address is blocked from protocol actions
    function isRestricted(address account) external view returns (bool);
}