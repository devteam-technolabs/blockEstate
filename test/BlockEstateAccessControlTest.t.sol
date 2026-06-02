// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";

contract BlockEstateAccessControlTest is Test {
    BlockEstateAccessControl public accessController;

    address public admin = address(0x1);
    address public complianceOfficer = address(0x2);
    address public securityGuard = address(0x3);
    address public emergencyAdmin = address(0x4);
    address public treasuryOperator = address(0x5);
    address public unauthorized = address(0x99);

    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
    bytes32 public constant ROLE_TREASURY_OPERATOR = keccak256("BLOCKESTATE_TREASURY_OPERATOR");

    function setUp() public {
        // Deploy with admin as the default admin
        vm.prank(admin);
        accessController = new BlockEstateAccessControl();

        // Note: With AccessControlDefaultAdminRules, granting roles immediately
        // might not work due to the 3-day delay. Use grantRole directly which
        // bypasses the delay for non-admin roles, but admin role changes require delay.

        // Grant roles using the standard grantRole (these are fine for non-admin roles)
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);

        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, securityGuard);

        vm.prank(admin);
        accessController.grantRole(ROLE_EMERGENCY_ADMIN, emergencyAdmin);

        vm.prank(admin);
        accessController.grantRole(ROLE_TREASURY_OPERATOR, treasuryOperator);

        // Warp time to bypass the 3-day delay for any admin operations if needed
        vm.warp(block.timestamp + 4 days);
    }

    function testDefaultAdminRole() public view {
        assertTrue(accessController.hasRole(accessController.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(accessController.hasRole(accessController.DEFAULT_ADMIN_ROLE(), unauthorized));
    }

    function testGrantRole() public {
        address newAdmin = address(0x100);

        // For granting admin role, we need to use the default admin rules
        // First, schedule the role change
        vm.prank(admin);
        accessController.beginDefaultAdminTransfer(newAdmin);

        // Warp past the delay
        vm.warp(block.timestamp + 4 days);

        // Accept the role
        vm.prank(newAdmin);
        accessController.acceptDefaultAdminTransfer();

        assertTrue(accessController.hasRole(accessController.DEFAULT_ADMIN_ROLE(), newAdmin));
    }

    function testRevokeRole() public {
        vm.prank(admin);
        accessController.revokeRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);

        assertFalse(accessController.hasRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer));
    }

    function testRenounceRole() public {
        vm.prank(complianceOfficer);
        accessController.renounceRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);

        assertFalse(accessController.hasRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer));
    }

    function testOnlyAdminCanGrantRoles() public {
        vm.expectRevert(); // AccessControlUnauthorizedAccount
        vm.prank(unauthorized);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, address(0x100));
    }

    function testEnforceAdmin() public {
        vm.prank(admin);
        accessController.enforceAdmin(admin);

        vm.expectRevert("NOT_ADMIN");
        vm.prank(admin);
        accessController.enforceAdmin(unauthorized);
    }

    function testEnforceFundsManager() public {
        vm.prank(admin);
        accessController.enforceFundsManager(treasuryOperator);

        vm.expectRevert("NOT_TREASURY");
        vm.prank(admin);
        accessController.enforceFundsManager(unauthorized);
    }

    function testRoleHierarchy() public {
        // Emergency admin should not have admin rights by default
        assertFalse(accessController.hasRole(accessController.DEFAULT_ADMIN_ROLE(), emergencyAdmin));

        // Grant emergency admin admin rights using the proper method
        vm.prank(admin);
        accessController.beginDefaultAdminTransfer(emergencyAdmin);

        vm.warp(block.timestamp + 4 days);

        vm.prank(emergencyAdmin);
        accessController.acceptDefaultAdminTransfer();

        assertTrue(accessController.hasRole(accessController.DEFAULT_ADMIN_ROLE(), emergencyAdmin));
    }

    function testMultipleRoleAssignment() public {
        address multiRoleUser = address(0x200);

        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, multiRoleUser);

        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, multiRoleUser);

        assertTrue(accessController.hasRole(ROLE_COMPLIANCE_OFFICER, multiRoleUser));
        assertTrue(accessController.hasRole(ROLE_SECURITY_GUARD, multiRoleUser));
    }

    function testKYCApproval() public {
        address user = address(0x300);
        vm.deal(user, 1 ether);

        vm.prank(complianceOfficer);
        accessController.approveKYC(user);

        assertTrue(accessController.isKYCApproved(user));
    }

    function testRevokeKYC() public {
        address user = address(0x301);
        vm.deal(user, 1 ether);

        vm.prank(complianceOfficer);
        accessController.approveKYC(user);

        assertTrue(accessController.isKYCApproved(user));

        vm.prank(complianceOfficer);
        accessController.revokeKYC(user);

        assertFalse(accessController.isKYCApproved(user));
    }

    function testSponsorAmount() public {
        uint256 initialSponsorAmount = accessController.sponsorAmount();
        assertEq(initialSponsorAmount, 0.00025 ether);

        uint256 newAmount = 0.0005 ether;
        vm.prank(admin);
        accessController.setSponsorAmount(newAmount);

        assertEq(accessController.sponsorAmount(), newAmount);
    }
}
