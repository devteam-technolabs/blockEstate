// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstateTokenizationFactory.sol";
import "../src/BlockEstateAssetIssuance.sol";
import "../src/BlockEstatePropertyToken.sol";
import "../src/BlockEstateRevenueDistributor.sol";

// Real Asset Issuance contract for testing - will be deployed after factory is known
contract TestAssetIssuance is BlockEstateAssetIssuance {
    constructor(address factory_, address router_) 
        BlockEstateAssetIssuance(factory_, router_) 
    {}
}

// Real Revenue Distributor for testing
contract TestRevenueDistributor is BlockEstateRevenueDistributor {
    constructor(address router_) 
        BlockEstateRevenueDistributor(router_) 
    {}
}

contract BlockEstateFactoryTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    BlockEstateAccessControl public accessController;
    BlockEstateRouter public router;
    BlockEstateTokenizationFactory public factory;
    BlockEstateAssetIssuance public assetIssuance;
    BlockEstateRevenueDistributor public revenueDistributor;
    MockERC20 public stableToken;
    MockReferralRewards public referralRewards;
    
    address public admin = address(0x1);
    address public complianceOfficer = address(0x2);
    address public treasury = address(0x3);
    address public backendSigner;
    address public investor = address(0x5);
    address public propertyOwner = address(0x6);
    address public propertyAdmin = address(0x7);
    address public referrer = address(0x8);
    address public securityGuard = address(0x9);
    address public emergencyAdmin = address(0x10);
    
    // Private keys for signing
    uint256 internal constant BACKEND_SIGNER_PRIVATE_KEY = 0x1234567890123456789012345678901234567890123456789012345678900001;
    uint256 internal constant INVESTOR_PRIVATE_KEY = 0x1234567890123456789012345678901234567890123456789012345678900002;
    
    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
    bytes32 public constant ROLE_TREASURY_OPERATOR = keccak256("BLOCKESTATE_TREASURY_OPERATOR");
    
    function setUp() public {
        // Derive the backend signer address from the private key
        backendSigner = vm.addr(BACKEND_SIGNER_PRIVATE_KEY);
        
        // Give ETH to all addresses that will receive KYC approval
        uint256 ethAmount = 1 ether;
        
        vm.deal(admin, ethAmount);
        vm.deal(complianceOfficer, ethAmount);
        vm.deal(treasury, ethAmount);
        vm.deal(backendSigner, ethAmount);
        vm.deal(investor, ethAmount);
        vm.deal(propertyOwner, ethAmount);
        vm.deal(propertyAdmin, ethAmount);
        vm.deal(referrer, ethAmount);
        vm.deal(securityGuard, ethAmount);
        vm.deal(emergencyAdmin, ethAmount);
        
        // Deploy Access Controller
        vm.prank(admin);
        accessController = new BlockEstateAccessControl();
        
        // Grant roles
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, securityGuard);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_EMERGENCY_ADMIN, emergencyAdmin);
        
        vm.prank(admin);
        accessController.grantRole(ROLE_TREASURY_OPERATOR, treasury);
        
        // Deploy Router
        router = new BlockEstateRouter(address(accessController));
        
        // Setup Router
        vm.prank(admin);
        router.setTreasury(treasury);
        
        // Deploy Mock Stable Token
        stableToken = new MockERC20("USD Coin", "USDC", 6);
        vm.prank(admin);
        router.setStableToken(address(stableToken));
        
        // Deploy Factory FIRST (before AssetIssuance)
        factory = new BlockEstateTokenizationFactory(address(router));
        
        // Now deploy Asset Issuance with the factory address (not this contract)
        assetIssuance = new TestAssetIssuance(address(factory), address(router));
        vm.prank(admin);
        router.setAssetIssuance(address(assetIssuance));
        
        // Set factory address in router
        vm.prank(admin);
        router.setFactory(address(factory));
        
        // Deploy Revenue Distributor
        revenueDistributor = new TestRevenueDistributor(address(router));
        vm.prank(admin);
        router.setRevenueDistributor(address(revenueDistributor));
        
        // Setup Referral Rewards
        referralRewards = new MockReferralRewards();
        vm.prank(admin);
        router.setReferralRewards(address(referralRewards));
        
        // Set Backend Signer (using the derived address)
        vm.prank(admin);
        factory.setBackendSigner(backendSigner);
        
        // Setup KYC for investors
        vm.prank(complianceOfficer);
        accessController.approveKYC(investor);
        
        vm.prank(complianceOfficer);
        accessController.approveKYC(referrer);
        
        vm.prank(complianceOfficer);
        accessController.approveKYC(propertyOwner);
        
        // Fund accounts with stable tokens
        stableToken.mint(investor, 100000 * 10**6);
        stableToken.mint(propertyOwner, 100000 * 10**6);
        stableToken.mint(referrer, 100000 * 10**6);
    }
    
    function testCreateProperty() public {
        vm.startPrank(admin);
        address property = factory.createProperty(
            "Luxury Apartment",
            "LUX",
            propertyAdmin,
            propertyOwner
        );
        vm.stopPrank();
        
        assertTrue(factory.isValidProperty(property));
        assertEq(factory.totalProperties(), 1);
        
        // Verify property token was created correctly
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertEq(token.name(), "Luxury Apartment");
        assertEq(token.symbol(), "LUX");
        assertEq(token.admin(), propertyAdmin);
        assertEq(token.assetOwner(), propertyOwner);
    }
    
    function testCreatePropertyFailsIfNotAdmin() public {
        vm.expectRevert("NOT_ADMIN");
        vm.prank(investor);
        factory.createProperty(
            "Luxury Apartment",
            "LUX",
            propertyAdmin,
            propertyOwner
        );
    }
    
    function testCreateMultipleProperties() public {
        string[] memory names = new string[](3);
        names[0] = "Property 1";
        names[1] = "Property 2";
        names[2] = "Property 3";
        
        for(uint i = 0; i < names.length; i++) {
            vm.prank(admin);
            address property = factory.createProperty(
                names[i],
                string(abi.encodePacked("P", vm.toString(i+1))),
                propertyAdmin,
                propertyOwner
            );
            
            assertTrue(factory.isValidProperty(property));
        }
        
        assertEq(factory.totalProperties(), 3);
    }
    
    function testInvest() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 investAmount = 10000 * 10**6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);
        
        vm.prank(investor);
        factory.invest(property, investAmount);
        
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 expectedTokens = investAmount - (investAmount * 500 / 10000); // 5% fee
        uint256 actualTokens = token.balanceOf(investor);
        
        assertEq(actualTokens, expectedTokens);
    }
    
    function testInvestWithDifferentAmounts() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100 * 10**6;
        amounts[1] = 500 * 10**6;
        amounts[2] = 1000 * 10**6;
        amounts[3] = 5000 * 10**6;
        amounts[4] = 10000 * 10**6;
        
        for(uint i = 0; i < amounts.length; i++) {
            vm.prank(investor);
            stableToken.approve(address(factory), amounts[i]);
            
            vm.prank(investor);
            factory.invest(property, amounts[i]);
        }
        
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 expectedTotal = 0;
        for(uint i = 0; i < amounts.length; i++) {
            expectedTotal += amounts[i] - (amounts[i] * 500 / 10000);
        }
        
        uint256 actualTotal = token.balanceOf(investor);
        assertApproxEqAbs(actualTotal, expectedTotal, 10**6);
    }
    
    function testInvestFailsIfInvalidProperty() public {
        address invalidProperty = address(0x999);
        uint256 investAmount = 1000 * 10**6;
        
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);
        
        vm.expectRevert("INVALID_PROPERTY");
        vm.prank(investor);
        factory.invest(invalidProperty, investAmount);
    }
    
    function testInvestFailsWithoutKYC() public {
        address nonKYCInvestor = address(0x999);
        vm.deal(nonKYCInvestor, 10 ether);
        stableToken.mint(nonKYCInvestor, 10000 * 10**6);
        
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 investAmount = 1000 * 10**6;
        vm.prank(nonKYCInvestor);
        stableToken.approve(address(factory), investAmount);
        
        vm.expectRevert("KYC_REQUIRED");
        vm.prank(nonKYCInvestor);
        factory.invest(property, investAmount);
    }
    
    function testPlatformFeeUpdate() public {
        uint256 newFee = 1000; // 10%
        vm.prank(admin);
        factory.setPlatformFeeBps(newFee);
        
        assertEq(factory.platformFeeBps(), newFee);
        
        // Test with new fee
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 investAmount = 10000 * 10**6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);
        
        vm.prank(investor);
        factory.invest(property, investAmount);
        
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 expectedTokens = investAmount - (investAmount * newFee / 10000);
        assertEq(token.balanceOf(investor), expectedTokens);
        
        // Reset fee for other tests
        vm.prank(admin);
        factory.setPlatformFeeBps(500);
    }
    
    function testPlatformFeeCannotExceedMax() public {
        uint256 invalidFee = 3000; // > 25% (MAX_PLATFORM_FEE = 2500)
        vm.expectRevert("FEE_TOO_HIGH");
        vm.prank(admin);
        factory.setPlatformFeeBps(invalidFee);
    }
    
    function testFiatInvestment() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 amount = 10000 * 10**6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_1"));
        
        bytes32 hash = keccak256(
            abi.encode(
                investor,
                property,
                amount,
                paymentId,
                address(factory),
                block.chainid
            )
        );
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BACKEND_SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 expectedTokens = amount - (amount * 500 / 10000);
        uint256 actualTokens = token.balanceOf(investor);
        
        assertEq(actualTokens, expectedTokens);
        assertTrue(factory.processedPayments(paymentId));
    }
    
    function testFiatInvestmentFailsWithInvalidSignature() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 amount = 10000 * 10**6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_invalid"));
        
        bytes32 hash = keccak256(
            abi.encode(
                investor,
                property,
                amount,
                paymentId,
                address(factory),
                block.chainid
            )
        );
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
        // Sign with wrong signer (investor private key instead of backendSigner)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(INVESTOR_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.expectRevert("INVALID_SIGNATURE");
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
    }
    
    function testFiatInvestmentFailsWithDuplicatePayment() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        uint256 amount = 10000 * 10**6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_duplicate"));
        
        bytes32 hash = keccak256(
            abi.encode(
                investor,
                property,
                amount,
                paymentId,
                address(factory),
                block.chainid
            )
        );
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BACKEND_SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // First transaction
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        
        // Second transaction with same paymentId
        vm.expectRevert("ALREADY_PROCESSED");
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
    }
    
    function testMultipleFiatInvestments() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        for(uint i = 0; i < 5; i++) {
            uint256 amount = 1000 * 10**6;
            bytes32 paymentId = keccak256(abi.encodePacked("payment_", i));
            
            bytes32 hash = keccak256(
                abi.encode(
                    investor,
                    property,
                    amount,
                    paymentId,
                    address(factory),
                    block.chainid
                )
            );
            bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(BACKEND_SIGNER_PRIVATE_KEY, digest);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            vm.prank(admin);
            factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        }
        
        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 expectedTotal = 5 * (1000 * 10**6 - (1000 * 10**6 * 500 / 10000));
        uint256 actualTotal = token.balanceOf(investor);
        assertApproxEqAbs(actualTotal, expectedTotal, 10**6);
        assertEq(factory.totalProperties(), 1);
    }
    
    function testSetBackendSigner() public {
        address newSigner = address(0x999);
        vm.prank(admin);
        factory.setBackendSigner(newSigner);
        
        assertEq(factory.backendSigner(), newSigner);
    }
    
    function testSetBackendSignerFailsIfNotAdmin() public {
        vm.expectRevert("NOT_ADMIN");
        vm.prank(investor);
        factory.setBackendSigner(address(0x999));
    }
    
    function testInvestFailsWhenProtocolPaused() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        // Pause protocol
        vm.prank(emergencyAdmin);
        accessController.pause();
        
        uint256 investAmount = 1000 * 10**6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);
        
        vm.expectRevert("PAUSED");
        vm.prank(investor);
        factory.invest(property, investAmount);
        
        // Unpause for other tests
        vm.prank(emergencyAdmin);
        accessController.unpause();
    }
    
    function testInvestFailsIfBlacklisted() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        // Blacklist investor
        vm.prank(securityGuard);
        accessController.blacklist(investor);
        
        uint256 investAmount = 1000 * 10**6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);
        
        vm.expectRevert("BLACKLISTED");
        vm.prank(investor);
        factory.invest(property, investAmount);
        
        // Unblacklist for other tests
        vm.prank(securityGuard);
        accessController.unblacklist(investor);
    }
}

// Mock ERC20 with 6 decimals (USDC style)
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

contract MockReferralRewards {
    mapping(address => uint256) public rewards;
    
    function registerReward(address user, uint256 amount) external {
        rewards[user] += amount;
    }
}