// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstatePropertyToken.sol";

contract MockRouterForToken {
    address public accessController;
    address public revenueDistributor;

    constructor(address _accessController) {
        accessController = _accessController;
    }

    function setRevenueDistributor(address _addr) external {
        revenueDistributor = _addr;
    }

    function getAccessController() external view returns (address) {
        return accessController;
    }
}

contract BlockEstatePropertyTokenTest is Test {
    BlockEstateAccessControl public accessController;
    MockRouterForToken public router;
    BlockEstatePropertyToken public propertyToken;

    address public admin;
    address public factory = address(0x2);
    address public propertyOwner = address(0x3);
    address public investor1 = address(0x4);
    address public investor2 = address(0x5);
    address public securityGuard = address(0x9);
    address public emergencyAdmin = address(0x10);

    uint256 public maxSupply = 1000000 * 10 ** 18;
    uint256 public sharePrice = 1 * 10 ** 6;

    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("BLOCKESTATE_EMERGENCY_ADMIN");

    function setUp() public {
        admin = address(this);

        uint256 ethAmount = 1 ether;
        vm.deal(investor1, ethAmount);
        vm.deal(investor2, ethAmount);
        vm.deal(propertyOwner, ethAmount);
        vm.deal(securityGuard, ethAmount);
        vm.deal(emergencyAdmin, ethAmount);
        vm.deal(address(0x100), ethAmount);
        vm.deal(address(0x101), ethAmount);

        accessController = new BlockEstateAccessControl();

        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, admin);
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, securityGuard);
        vm.prank(admin);
        accessController.grantRole(ROLE_EMERGENCY_ADMIN, emergencyAdmin);

        router = new MockRouterForToken(address(accessController));

        vm.prank(admin);
        accessController.approveKYC(investor1);
        vm.prank(admin);
        accessController.approveKYC(investor2);

        propertyToken = new BlockEstatePropertyToken(
            address(router), factory, "Test Property", "TEST", admin, propertyOwner, maxSupply, sharePrice
        );
    }

    function testTokenInitialization() public view {
        assertEq(propertyToken.name(), "Test Property");
        assertEq(propertyToken.symbol(), "TEST");
        assertEq(propertyToken.admin(), admin);
        assertEq(propertyToken.assetOwner(), propertyOwner);
        assertEq(propertyToken.factory(), factory);
        assertEq(propertyToken.maxSupply(), maxSupply);
        assertEq(propertyToken.sharePrice(), sharePrice);
    }

    function testMintByFactory() public {
        uint256 stableAmount = 10000 * 10 ** 6;
        uint256 expectedShares = (stableAmount * 1e18) / sharePrice;

        vm.prank(factory);
        uint256 shares = propertyToken.mint(investor1, stableAmount);

        assertEq(shares, expectedShares);
        assertEq(propertyToken.balanceOf(investor1), expectedShares);
        assertEq(propertyToken.totalSupply(), expectedShares);
    }

    function testMintFailsIfNotFactory() public {
        uint256 stableAmount = 10000 * 10 ** 6;
        vm.expectRevert("ONLY_FACTORY");
        vm.prank(admin);
        propertyToken.mint(investor1, stableAmount);
    }

    function testTransferWithCompliance() public {
        uint256 stableAmount = 10000 * 10 ** 6;
        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        uint256 balance = propertyToken.balanceOf(investor1);
        uint256 transferAmount = balance / 2;

        vm.prank(investor1);
        propertyToken.transfer(investor2, transferAmount);

        assertEq(propertyToken.balanceOf(investor1), balance - transferAmount);
        assertEq(propertyToken.balanceOf(investor2), transferAmount);
    }

    function testTransferFailsIfSenderNotKYC() public {
        address nonKYCUser = address(0x100);
        uint256 stableAmount = 10000 * 10 ** 6;

        vm.prank(factory);
        propertyToken.mint(nonKYCUser, stableAmount);

        vm.expectRevert("SENDER_NOT_KYC");
        vm.prank(nonKYCUser);
        propertyToken.transfer(investor2, 100);
    }

    function testTransferFailsIfRecipientNotKYC() public {
        address nonKYCUser = address(0x100);
        uint256 stableAmount = 10000 * 10 ** 6;

        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        vm.expectRevert("RECIPIENT_NOT_KYC");
        vm.prank(investor1);
        propertyToken.transfer(nonKYCUser, 100);
    }

    function testTransferFailsIfSenderBlacklisted() public {
        uint256 stableAmount = 10000 * 10 ** 6;

        vm.prank(securityGuard);
        accessController.blacklist(investor1);

        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        vm.expectRevert("SENDER_BLACKLISTED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 100);
    }

    function testTransferFailsIfProtocolPaused() public {
        uint256 stableAmount = 10000 * 10 ** 6;

        vm.prank(emergencyAdmin);
        accessController.pause();

        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        vm.expectRevert("PROTOCOL_PAUSED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 100);

        vm.prank(emergencyAdmin);
        accessController.unpause();
    }

    function testTransferFromWithApproval() public {
        uint256 stableAmount = 10000 * 10 ** 6;
        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        uint256 allowanceAmount = propertyToken.balanceOf(investor1) / 2;

        vm.prank(investor1);
        propertyToken.approve(investor2, allowanceAmount);

        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, allowanceAmount);

        assertEq(propertyToken.balanceOf(investor1), allowanceAmount);
        assertEq(propertyToken.balanceOf(investor2), allowanceAmount);
        assertEq(propertyToken.allowance(investor1, investor2), 0);
    }

    function testMultipleMints() public {
        uint256 stableAmount1 = 10000 * 10 ** 6;
        uint256 stableAmount2 = 5000 * 10 ** 6;

        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount1);

        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount2);

        uint256 expectedShares1 = (stableAmount1 * 1e18) / sharePrice;
        uint256 expectedShares2 = (stableAmount2 * 1e18) / sharePrice;

        assertEq(propertyToken.balanceOf(investor1), expectedShares1 + expectedShares2);
    }

    function testTransferFromWithoutApproval() public {
        uint256 stableAmount = 10000 * 10 ** 6;
        vm.prank(factory);
        propertyToken.mint(investor1, stableAmount);

        vm.expectRevert();
        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, 100);
    }

    function testCalculateShares() public view {
        uint256 stableAmount = 10000 * 10 ** 6;
        uint256 expectedShares = (stableAmount * 1e18) / sharePrice;
        assertEq(propertyToken.calculateShares(stableAmount), expectedShares);
    }
}
