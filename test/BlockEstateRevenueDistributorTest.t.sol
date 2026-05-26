// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstateRevenueDistributor.sol";
import "../src/BlockEstatePropertyToken.sol";
import "../src/BlockEstateTokenizationFactory.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}

contract BlockEstateRevenueDistributorTest is Test {
    BlockEstateAccessControl public accessController;
    BlockEstateRouter public router;
    BlockEstateRevenueDistributor public distributor;
    BlockEstatePropertyToken public propertyToken;
    MockERC20 public stableToken;
    
    address public admin = address(0x1);
    address public propertyOwner = address(0x2);
    address public investor1 = address(0x3);
    address public investor2 = address(0x4);
    address public investor3 = address(0x5);
    
    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    
    function setUp() public {
        accessController = new BlockEstateAccessControl();
        
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, admin);
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, admin);
        
        router = new BlockEstateRouter(address(accessController));
        
        stableToken = new MockERC20("USD Coin", "USDC", 6);
        vm.prank(admin);
        router.setStableToken(address(stableToken));
        
        distributor = new BlockEstateRevenueDistributor(address(router));
        vm.prank(admin);
        router.setRevenueDistributor(address(distributor));
        
        propertyToken = new BlockEstatePropertyToken(
            address(router),
            address(this),
            "Test Property",
            "TEST",
            admin,
            propertyOwner
        );
        
        vm.prank(admin);
        accessController.approveKYC(investor1);
        vm.prank(admin);
        accessController.approveKYC(investor2);
        vm.prank(admin);
        accessController.approveKYC(investor3);
        
        stableToken.mint(propertyOwner, 100000 * 10**6);
        stableToken.mint(investor1, 10000 * 10**6);
        stableToken.mint(investor2, 10000 * 10**6);
        stableToken.mint(investor3, 10000 * 10**6);
    }
    
    function mintTokensForInvestors() internal {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 ether;
        amounts[1] = 2000 ether;
        amounts[2] = 3000 ether;
        
        propertyToken.mint(investor1, amounts[0]);
        propertyToken.mint(investor2, amounts[1]);
        propertyToken.mint(investor3, amounts[2]);
    }
    
    function testDepositRevenue() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        assertTrue(distributor.accRevenuePerToken(address(propertyToken)) > 0);
    }
    
    function testDepositRevenueFailsIfNotPropertyOwner() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(investor1);
        stableToken.approve(address(distributor), revenueAmount);
        
        vm.expectRevert("NOT_PROPERTY_OWNER");
        vm.prank(investor1);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
    }
    
    function testClaimRewards() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        uint256 initialBalance = stableToken.balanceOf(investor1);
        
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
        
        uint256 finalBalance = stableToken.balanceOf(investor1);
        assertTrue(finalBalance > initialBalance);
    }
    
    function testMultipleClaims() public {
        mintTokensForInvestors();
        
        // First deposit
        uint256 revenueAmount1 = 5000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount1);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount1);
        
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
        
        uint256 balanceAfterFirstClaim = stableToken.balanceOf(investor1);
        
        // Second deposit
        uint256 revenueAmount2 = 5000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount2);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount2);
        
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
        
        uint256 balanceAfterSecondClaim = stableToken.balanceOf(investor1);
        assertTrue(balanceAfterSecondClaim > balanceAfterFirstClaim);
    }
    
    function testPendingRevenueCalculation() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        uint256 pending = distributor.pendingRevenue(address(propertyToken), investor1);
        assertTrue(pending > 0);
        
        // Pending should match what they would receive
        uint256 totalSupply = propertyToken.totalSupply();
        uint256 investorBalance = propertyToken.balanceOf(investor1);
        uint256 expectedPending = (revenueAmount * investorBalance) / totalSupply;
        
        // Allow for small rounding differences
        assertApproxEqAbs(pending, expectedPending, 10**6);
    }
    
    function testUpdateOnTransfer() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        uint256 pendingBeforeTransfer = distributor.pendingRevenue(address(propertyToken), investor1);
        
        // Transfer tokens
        vm.prank(investor1);
        propertyToken.transfer(investor2, 500 ether);
        
        uint256 pendingAfterTransfer = distributor.pendingRevenue(address(propertyToken), investor1);
        
        // Pending should be updated after transfer
        assertTrue(pendingAfterTransfer < pendingBeforeTransfer);
    }
    
    function testClaimFailsIfNoRewards() public {
        mintTokensForInvestors();
        
        vm.expectRevert("NO_REWARD");
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
    }
    
    function testClaimFailsIfBlacklisted() public {
        mintTokensForInvestors();
        
        uint256 revenueAmount = 10000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        vm.prank(admin);
        accessController.blacklist(investor1);
        
        vm.expectRevert("BLACKLISTED");
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
    }
    
    function testDustAccumulation() public {
        // Mint odd number of tokens to create dust
        propertyToken.mint(investor1, 1234 ether);
        propertyToken.mint(investor2, 2345 ether);
        propertyToken.mint(investor3, 3456 ether);
        
        uint256 revenueAmount = 1000 * 10**6;
        vm.prank(propertyOwner);
        stableToken.approve(address(distributor), revenueAmount);
        vm.prank(propertyOwner);
        distributor.depositRevenue(address(propertyToken), revenueAmount);
        
        uint256 leftover = distributor.leftover(address(propertyToken));
        assertTrue(leftover < revenueAmount);
    }
    
    function testMultipleRevenueDeposits() public {
        mintTokensForInvestors();
        
        uint256 totalRevenue = 0;
        
        for(uint i = 0; i < 5; i++) {
            uint256 revenueAmount = 1000 * 10**6;
            totalRevenue += revenueAmount;
            
            vm.prank(propertyOwner);
            stableToken.approve(address(distributor), revenueAmount);
            vm.prank(propertyOwner);
            distributor.depositRevenue(address(propertyToken), revenueAmount);
        }
        
        vm.prank(investor1);
        distributor.claim(address(propertyToken));
        
        uint256 totalSupply = propertyToken.totalSupply();
        uint256 investorBalance = propertyToken.balanceOf(investor1);
        uint256 expectedReward = (totalRevenue * investorBalance) / totalSupply;
        uint256 actualReward = stableToken.balanceOf(investor1);
        
        assertApproxEqAbs(actualReward, expectedReward, 10**6);
    }
}