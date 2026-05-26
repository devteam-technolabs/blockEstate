// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstatePropertyToken.sol";
import "../src/BlockEstateTokenizationFactory.sol";
import "../src/BlockEstateAssetIssuance.sol";

contract MockRouter {
    address public accessController;
    address public revenueDistributor;
    address public factory;
    
    constructor(address _accessController) {
        accessController = _accessController;
    }
    
    function setRevenueDistributor(address _addr) external {
        revenueDistributor = _addr;
    }
    
    function setFactory(address _factory) external {
        factory = _factory;
    }
}

contract BlockEstatePropertyTokenTest is Test {
    BlockEstateAccessControl public accessController;
    MockRouter public router;
    BlockEstatePropertyToken public propertyToken;
    
    address public admin = address(0x1);
    address public factory = address(0x2);
    address public propertyOwner = address(0x3);
    address public investor1 = address(0x4);
    address public investor2 = address(0x5);
    address public blacklistedUser = address(0x6);
    
    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    
    function setUp() public {
        accessController = new BlockEstateAccessControl();
        
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, admin);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, admin);
        
        router = new MockRouter(address(accessController));
        
        vm.prank(admin);
        accessController.approveKYC(investor1);
        vm.prank(admin);
        accessController.approveKYC(investor2);
        
        propertyToken = new BlockEstatePropertyToken(
            address(router),
            factory,
            "Test Property",
            "TEST",
            admin,
            propertyOwner
        );
    }
    
    function testTokenInitialization() public view {
        assertEq(propertyToken.name(), "Test Property");
        assertEq(propertyToken.symbol(), "TEST");
        assertEq(propertyToken.admin(), admin);
        assertEq(propertyToken.assetOwner(), propertyOwner);
        assertEq(propertyToken.factory(), factory);
    }
    
    function testMintByFactory() public {
        uint256 mintAmount = 1000 ether;
        vm.prank(factory);
        propertyToken.mint(investor1, mintAmount);
        
        assertEq(propertyToken.balanceOf(investor1), mintAmount);
        assertEq(propertyToken.totalSupply(), mintAmount);
    }
    
    function testMintFailsIfNotFactory() public {
        vm.expectRevert("ONLY_FACTORY");
        vm.prank(admin);
        propertyToken.mint(investor1, 1000 ether);
    }
    
    function testTransferWithCompliance() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
        
        assertEq(propertyToken.balanceOf(investor1), 500 ether);
        assertEq(propertyToken.balanceOf(investor2), 500 ether);
    }
    
    function testTransferFailsIfSenderNotKYC() public {
        address nonKYCUser = address(0x100);
        
        vm.prank(factory);
        propertyToken.mint(nonKYCUser, 1000 ether);
        
        vm.expectRevert("SENDER_NOT_KYC");
        vm.prank(nonKYCUser);
        propertyToken.transfer(investor2, 500 ether);
    }
    
    function testTransferFailsIfRecipientNotKYC() public {
        address nonKYCUser = address(0x100);
        
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert("RECIPIENT_NOT_KYC");
        vm.prank(investor1);
        propertyToken.transfer(nonKYCUser, 500 ether);
    }
    
    function testTransferFailsIfSenderBlacklisted() public {
        vm.prank(admin);
        accessController.blacklist(investor1);
        
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert("SENDER_BLACKLISTED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
    }
    
    function testTransferFailsIfProtocolPaused() public {
        vm.prank(admin);
        accessController.pause();
        
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert("PROTOCOL_PAUSED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
    }
    
    function testBatchTransfer() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        address[] memory recipients = new address[](3);
        recipients[0] = investor2;
        recipients[1] = address(0x100);
        recipients[2] = address(0x101);
        
        vm.prank(admin);
        accessController.approveKYC(address(0x100));
        vm.prank(admin);
        accessController.approveKYC(address(0x101));
        
        uint256 transferAmount = 100 ether;
        
        for(uint i = 0; i < recipients.length; i++) {
            vm.prank(investor1);
            propertyToken.transfer(recipients[i], transferAmount);
        }
        
        assertEq(propertyToken.balanceOf(investor1), 700 ether);
        for(uint i = 0; i < recipients.length; i++) {
            assertEq(propertyToken.balanceOf(recipients[i]), transferAmount);
        }
    }
    
    function testTransferFromWithApproval() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.prank(investor1);
        propertyToken.approve(investor2, 500 ether);
        
        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, 500 ether);
        
        assertEq(propertyToken.balanceOf(investor1), 500 ether);
        assertEq(propertyToken.balanceOf(investor2), 500 ether);
        assertEq(propertyToken.allowance(investor1, investor2), 0);
    }
    
    function testBurn() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.prank(investor1);
        propertyToken.transfer(address(0), 500 ether);
        
        assertEq(propertyToken.balanceOf(investor1), 500 ether);
        assertEq(propertyToken.totalSupply(), 500 ether);
    }
}