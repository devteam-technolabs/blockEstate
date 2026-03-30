// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title BlockEstateConfig
 * @dev Shared constants and role definitions across the protocol.
 */
abstract contract BlockEstateConfig {

    /*//////////////////////////////////////////////////////////////
                        NUMERIC CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant BPS = 10_000;
    uint256 internal constant MAX_PLATFORM_FEE = 2_500; // 25%
    uint256 internal constant INVESTMENT_GRACE_PERIOD = 14 days;

    uint256 internal constant STABLE_TOKEN_UNIT = 1e6;
    uint256 internal constant INTERNAL_SCALING_FACTOR = 1e14;
    uint128 internal constant ACCURACY_MULTIPLIER = 5e31;

    /*//////////////////////////////////////////////////////////////
                            ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ROLE_SECURITY_GUARD =
        keccak256("BLOCKESTATE_SECURITY_GUARD");

    bytes32 public constant ROLE_TREASURY_OPERATOR =
        keccak256("BLOCKESTATE_TREASURY_OPERATOR");

    bytes32 public constant ROLE_COMPLIANCE_OFFICER =
        keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");

    bytes32 public constant ROLE_EMERGENCY_ADMIN =
        keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
    
    bytes32 public constant ROLE_BACKEND_SIGNER =
        keccak256("BLOCKESTATE_BACKEND_SIGNER");
}