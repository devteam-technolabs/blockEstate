// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstateTokenizationFactory.sol";
import "../src/BlockEstateAssetIssuance.sol";
import "../src/BlockEstatePropertyToken.sol";

contract MockAssetIssuance {
    function createPropertyToken(
        string memory name,
        string memory symbol,
        address admin,
        address owner
    ) external returns (address) {
        return address(new MockPropertyToken(name, symbol, admin, owner));
    }
}

contract MockPropertyToken {
    string public name;
    string public symbol;
    address public admin;
    address public assetOwner;
    
    constructor(string memory _name, string memory _symbol, address _admin, address _owner) {
        name = _name;
        symbol = _symbol;
        admin = _admin;
        assetOwner = _owner;
    }
}

contract BlockEstateFactoryTest is Test {
    BlockEstateAccessControl public accessController;
    BlockEstateRouter public router;
    BlockEstateTokenizationFactory public factory;
    MockAssetIssuance public assetIssuance;
    MockERC20 public stableToken;
    
    address public admin = address(0x1);
    address public complianceOfficer = address(0x2);
    address public treasury = address(0x3);
    address public backendSigner = address(0x4);
    address public investor = address(0x5);
    address public propertyOwner = address(0x6);
    address public propertyAdmin = address(0x7);
    address public referrer = address(0x8);
    
    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    
    function setUp() public {
        accessController = new BlockEstateAccessControl();
        
        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);
        
        router = new BlockEstateRouter(address(accessController));
        
        vm.prank(admin);
        router.setTreasury(treasury);
        
        stableToken = new MockERC20("USD Coin", "USDC", 6);
        vm.prank(admin);
        router.setStableToken(address(stableToken));
        
        assetIssuance = new MockAssetIssuance();
        vm.prank(admin);
        router.setAssetIssuance(address(assetIssuance));
        
        factory = new BlockEstateTokenizationFactory(address(router));
        
        vm.prank(admin);
        router.setFactory(address(factory));
        
        vm.prank(admin);
        factory.setBackendSigner(backendSigner);
        
        vm.prank(complianceOfficer);
        accessController.approveKYC(investor);
        vm.prank(complianceOfficer);
        accessController.approveKYC(referrer);
        
        stableToken.mint(investor, 100000 * 10**6);
        stableToken.mint(propertyOwner, 100000 * 10**6);
    }
    
    function testCreateProperty() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Luxury Apartment",
            "LUX",
            propertyAdmin,
            propertyOwner
        );
        
        assertTrue(factory.isValidProperty(property));
        assertEq(factory.totalProperties(), 1);
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
        
        MockERC20 token = MockERC20(property);
        uint256 expectedTokens = investAmount - (investAmount * 500 / 10000); // 5% fee
        assertEq(token.balanceOf(investor), expectedTokens);
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
        
        MockERC20 token = MockERC20(property);
        uint256 expectedTotal = 0;
        for(uint i = 0; i < amounts.length; i++) {
            expectedTotal += amounts[i] - (amounts[i] * 500 / 10000);
        }
        
        assertEq(token.balanceOf(investor), expectedTotal);
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
        
        MockERC20 token = MockERC20(property);
        uint256 expectedTokens = investAmount - (investAmount * newFee / 10000);
        assertEq(token.balanceOf(investor), expectedTokens);
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
        bytes32 digest = hash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSigner, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        
        MockERC20 token = MockERC20(property);
        uint256 expectedTokens = amount - (amount * 500 / 10000);
        assertEq(token.balanceOf(investor), expectedTokens);
        assertTrue(factory.processedPayments(paymentId));
    }
    
    function testFiatInvestmentWithReferral() public {
        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property",
            "TEST",
            propertyAdmin,
            propertyOwner
        );
        
        MockReferralRewards referralRewards = new MockReferralRewards();
        vm.prank(admin);
        router.setReferralRewards(address(referralRewards));
        
        uint256 amount = 10000 * 10**6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_referral"));
        
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
        bytes32 digest = hash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSigner, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(admin);
        factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        
        assertTrue(referralRewards.rewards(investor) > 0);
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
            bytes32 digest = hash.toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSigner, digest);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            vm.prank(admin);
            factory.processFiatInvestment(investor, property, amount, paymentId, signature);
        }
        
        MockERC20 token = MockERC20(property);
        uint256 expectedTotal = 5 * (1000 * 10**6 - (1000 * 10**6 * 500 / 10000));
        assertEq(token.balanceOf(investor), expectedTotal);
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
}

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