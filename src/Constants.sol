// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title BlockEstate Global Configuration
 * @author devItechnolabs
 *
 * @notice
 * Core configuration parameters shared by the BlockEstate
 * real-estate tokenization protocol.
 */
abstract contract BlockEstateConfig {

    /*//////////////////////////////////////////////////////////////
                        NUMERIC CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Basis point denominator used for percentage math
    uint256 internal constant BPS = 10_000;

    /// @dev Maximum platform fee (25%)
    uint256 internal constant MAX_PLATFORM_FEE = 2_500;

    /// @dev Grace window used for extended investment operations
    uint256 internal constant INVESTMENT_GRACE_PERIOD = 14 days;

    /// @dev Precision helper for tokens with 6 decimals
    uint256 internal constant STABLE_TOKEN_UNIT = 1e6;

    /// @dev Additional scaling constant used in financial calculations
    uint256 internal constant INTERNAL_SCALING_FACTOR = 1e14;

    /// @dev Multiplier used for high precision accounting
    uint128 internal constant ACCURACY_MULTIPLIER = 5e31;

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Governance role responsible for address restrictions
    bytes32 public constant ROLE_SECURITY_GUARD =
        keccak256("BLOCKESTATE_SECURITY_GUARD");

    /// @notice Treasury operator role for off-chain settlement sync
    bytes32 public constant ROLE_TREASURY_OPERATOR =
        keccak256("BLOCKESTATE_TREASURY_OPERATOR");

    /// @notice Identity verification authority
    bytes32 public constant ROLE_COMPLIANCE_OFFICER =
        keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");

    /// @notice Emergency role capable of halting protocol activity
    bytes32 public constant ROLE_EMERGENCY_ADMIN =
        keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
}