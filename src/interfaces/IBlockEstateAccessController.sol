// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateAccessController {
    function enforceAdmin(address account) external view;
    function enforceFundsManager(address account) external view;
    function isKYCApproved(address user) external view returns (bool);
    function isBlacklisted(address user) external view returns (bool);
    function isProtocolPaused() external view returns (bool);
    function owner() external view returns (address);
    function isBackendSigner(address account) external view returns (bool);

    // Role constant getters
    function ROLE_SECURITY_GUARD() external view returns (bytes32);
    function ROLE_TREASURY_OPERATOR() external view returns (bytes32);
    function ROLE_COMPLIANCE_OFFICER() external view returns (bytes32);
    function ROLE_EMERGENCY_ADMIN() external view returns (bytes32);
    function ROLE_BACKEND_SIGNER() external view returns (bytes32);
}
