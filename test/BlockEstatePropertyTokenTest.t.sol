// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstatePropertyToken.sol";

// Mock Router for testing that implements required methods
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
    
    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
    
    function setUp() public {
        // The test contract itself becomes the default admin
        admin = address(this);
        
        // Give ETH to addresses that need gas sponsorship
        uint256 ethAmount = 1 ether;
        vm.deal(investor1, ethAmount);
        vm.deal(investor2, ethAmount);
        vm.deal(propertyOwner, ethAmount);
        vm.deal(securityGuard, ethAmount);
        vm.deal(emergencyAdmin, ethAmount);
        vm.deal(address(0x100), ethAmount);
        vm.deal(address(0x101), ethAmount);
        
        // Deploy Access Controller (admin will be the test contract)
        accessController = new BlockEstateAccessControl();
        
        // Grant roles - now the test contract is the admin, so this works
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, admin);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, securityGuard);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_EMERGENCY_ADMIN, emergencyAdmin);
        
        // Deploy Mock Router
        router = new MockRouterForToken(address(accessController));
        
        // Approve KYC for investors (using admin which is the test contract)
        vm.prank(admin);
        accessController.approveKYC(investor1);
        
        vm.prank(admin);
        accessController.approveKYC(investor2);
        
        // Deploy Property Token
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
        vm.prank(securityGuard);
        accessController.blacklist(investor1);
        
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert("SENDER_BLACKLISTED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
    }
    
    function testTransferFailsIfProtocolPaused() public {
        vm.prank(emergencyAdmin);
        accessController.pause();
        
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert("PROTOCOL_PAUSED");
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
        
        // Unpause for other tests
        vm.prank(emergencyAdmin);
        accessController.unpause();
    }
    
    function testBatchTransfer() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        address[] memory recipients = new address[](3);
        recipients[0] = investor2;
        recipients[1] = address(0x100);
        recipients[2] = address(0x101);
        
        // Approve KYC for recipient addresses
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
        
        uint256 initialSupply = propertyToken.totalSupply();
        uint256 burnAmount = 500 ether;
        
        // Transfer to zero address is not allowed in modern ERC20, 
        // so we need to test burn through a different method
        // Since the contract doesn't have a public burn function,
        // we'll test that transfers to zero address are rejected
        vm.expectRevert(); // ERC20InvalidReceiver error
        vm.prank(investor1);
        propertyToken.transfer(address(0), burnAmount);
        
        // Verify balance hasn't changed
        assertEq(propertyToken.balanceOf(investor1), 1000 ether);
        assertEq(propertyToken.totalSupply(), initialSupply);
    }
    
    function testMultipleMints() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.prank(factory);
        propertyToken.mint(investor1, 500 ether);
        
        assertEq(propertyToken.balanceOf(investor1), 1500 ether);
        assertEq(propertyToken.totalSupply(), 1500 ether);
    }
    
    function testTransferFromWithoutApproval() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert();
        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, 500 ether);
    }
    
    function testTransferWithInsufficientBalance() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        vm.expectRevert();
        vm.prank(investor1);
        propertyToken.transfer(investor2, 2000 ether);
    }
    
    function testApproveAndSpendMultiple() public {
        vm.prank(factory);
        propertyToken.mint(investor1, 1000 ether);
        
        // Approve investor2 to spend 500 tokens
        vm.prank(investor1);
        propertyToken.approve(investor2, 500 ether);
        
        // Spend 300 tokens
        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, 300 ether);
        
        // Check remaining allowance
        uint256 remainingAllowance = propertyToken.allowance(investor1, investor2);
        assertEq(remainingAllowance, 200 ether);
        
        // Spend remaining 200 tokens
        vm.prank(investor2);
        propertyToken.transferFrom(investor1, investor2, 200 ether);
        
        // Check final balances
        assertEq(propertyToken.balanceOf(investor1), 500 ether);
        assertEq(propertyToken.balanceOf(investor2), 500 ether);
        assertEq(propertyToken.allowance(investor1, investor2), 0);
    }
}