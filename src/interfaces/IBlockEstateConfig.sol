// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IBlockEstateConfig
 * @dev Interface for protocol configuration constants and enums
 */
interface IBlockEstateConfig {
    // Property status enum (mirroring BlockEstateConfig)
    enum PropertyStatus {
        FUNDRAISING,
        ACTIVE,
        SOLD,
        LIQUIDATED,
        PAUSED
    }

    // Constants
    function BPS() external view returns (uint256);
    function MAX_PLATFORM_FEE() external view returns (uint256);
    function INVESTMENT_GRACE_PERIOD() external view returns (uint256);
    function TIMELOCK_DELAY() external view returns (uint256);
    function MAX_SPONSOR_AMOUNT() external view returns (uint256);

    // Role constants
    function ROLE_SECURITY_GUARD() external view returns (bytes32);
    function ROLE_TREASURY_OPERATOR() external view returns (bytes32);
    function ROLE_COMPLIANCE_OFFICER() external view returns (bytes32);
    function ROLE_EMERGENCY_ADMIN() external view returns (bytes32);
    function ROLE_BACKEND_SIGNER() external view returns (bytes32);
}
