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
import "../src/referral/BlockEstateReferralRewards.sol";

contract TestAssetIssuance is BlockEstateAssetIssuance {
    constructor(address factory_, address router_) BlockEstateAssetIssuance(factory_, router_) {}
}

contract TestRevenueDistributor is BlockEstateRevenueDistributor {
    constructor(address router_) BlockEstateRevenueDistributor(router_) {}
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
    BlockEstateReferralRewards public referralRewards;

    address public admin;
    address public complianceOfficer = address(0x2);
    address public treasury = address(0x3);
    address public backendSigner;
    address public investor = address(0x5);
    address public propertyOwner = address(0x6);
    address public propertyAdmin = address(0x7);
    address public referrer = address(0x8);
    address public securityGuard = address(0x9);
    address public emergencyAdmin = address(0x10);

    uint256 internal constant BACKEND_SIGNER_PRIVATE_KEY = 0x4;

    bytes32 public constant ROLE_COMPLIANCE_OFFICER = keccak256("BLOCKESTATE_COMPLIANCE_OFFICER");
    bytes32 public constant ROLE_SECURITY_GUARD = keccak256("BLOCKESTATE_SECURITY_GUARD");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("BLOCKESTATE_EMERGENCY_ADMIN");
    bytes32 public constant ROLE_TREASURY_OPERATOR = keccak256("BLOCKESTATE_TREASURY_OPERATOR");

    function setUp() public {
        admin = address(this);
        backendSigner = vm.addr(BACKEND_SIGNER_PRIVATE_KEY);

        uint256 ethAmount = 1 ether;
        vm.deal(complianceOfficer, ethAmount);
        vm.deal(treasury, ethAmount);
        vm.deal(backendSigner, ethAmount);
        vm.deal(investor, ethAmount);
        vm.deal(propertyOwner, ethAmount);
        vm.deal(propertyAdmin, ethAmount);
        vm.deal(referrer, ethAmount);
        vm.deal(securityGuard, ethAmount);
        vm.deal(emergencyAdmin, ethAmount);

        accessController = new BlockEstateAccessControl();

        vm.prank(admin);
        accessController.grantRole(ROLE_COMPLIANCE_OFFICER, complianceOfficer);
        vm.prank(admin);
        accessController.grantRole(ROLE_SECURITY_GUARD, securityGuard);
        vm.prank(admin);
        accessController.grantRole(ROLE_EMERGENCY_ADMIN, emergencyAdmin);
        vm.prank(admin);
        accessController.grantRole(ROLE_TREASURY_OPERATOR, treasury);
        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_BACKEND_SIGNER(), backendSigner);

        router = new BlockEstateRouter(address(accessController));

        stableToken = new MockERC20("USD Coin", "USDC", 6);

        factory = new BlockEstateTokenizationFactory(address(router));

        assetIssuance = new TestAssetIssuance(address(factory), address(router));

        revenueDistributor = new TestRevenueDistributor(address(router));

        referralRewards = new BlockEstateReferralRewards(address(router));

        // Schedule all router changes
        vm.prank(admin);
        router.setTreasury(treasury);

        vm.prank(admin);
        router.setStableToken(address(stableToken));

        vm.prank(admin);
        router.setAssetIssuance(address(assetIssuance));

        vm.prank(admin);
        router.setFactory(address(factory));

        vm.prank(admin);
        router.setRevenueDistributor(address(revenueDistributor));

        vm.prank(admin);
        router.setReferralRewards(address(referralRewards));

        // Warp time past the timelock delay (2 days)
        vm.warp(block.timestamp + 3 days);

        // Execute all router changes
        vm.prank(admin);
        router.executeSetTreasury(treasury);

        vm.prank(admin);
        router.executeSetStableToken(address(stableToken));

        vm.prank(admin);
        router.executeSetAssetIssuance(address(assetIssuance));

        vm.prank(admin);
        router.executeSetFactory(address(factory));

        vm.prank(admin);
        router.executeSetRevenueDistributor(address(revenueDistributor));

        vm.prank(admin);
        router.executeSetReferralRewards(address(referralRewards));

        // Approve KYC using compliance officer
        vm.prank(complianceOfficer);
        accessController.approveKYC(investor);
        vm.prank(complianceOfficer);
        accessController.approveKYC(referrer);
        vm.prank(complianceOfficer);
        accessController.approveKYC(propertyOwner);

        stableToken.mint(investor, 100000 * 10 ** 6);
        stableToken.mint(propertyOwner, 100000 * 10 ** 6);
        stableToken.mint(referrer, 100000 * 10 ** 6);
        stableToken.mint(address(referralRewards), 100000 * 10 ** 6);
    }

    function testCreateProperty() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Luxury Apartment", "LUX", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        assertTrue(factory.isValidProperty(property));
        assertEq(factory.totalProperties(), 1);

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertEq(token.name(), "Luxury Apartment");
        assertEq(token.symbol(), "LUX");
        assertEq(token.admin(), propertyAdmin);
        assertEq(token.assetOwner(), propertyOwner);
        assertEq(token.maxSupply(), maxSupply);
        assertEq(token.sharePrice(), sharePrice);
    }

    function testCreatePropertyFailsIfNotAdmin() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.expectRevert("NOT_ADMIN");
        vm.prank(investor);
        factory.createProperty(
            "Luxury Apartment", "LUX", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );
    }

    function testCreateMultipleProperties() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(admin);
            address property = factory.createProperty(
                string(abi.encodePacked("Property ", vm.toString(i + 1))),
                string(abi.encodePacked("P", vm.toString(i + 1))),
                propertyAdmin,
                propertyOwner,
                maxSupply,
                sharePrice,
                valuation,
                targetRaise
            );
            assertTrue(factory.isValidProperty(property));
        }

        assertEq(factory.totalProperties(), 3);
    }

    function testInvest() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        uint256 investAmount = 10000 * 10 ** 6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);

        vm.prank(investor);
        factory.invest(property, investAmount);

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        uint256 fee = (investAmount * 500) / 10000;
        uint256 net = investAmount - fee;
        uint256 expectedNetShares = (net * 1e18) / sharePrice;

        assertEq(token.balanceOf(investor), expectedNetShares);
    }

    function testInvestWithDifferentAmounts() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100 * 10 ** 6;
        amounts[1] = 500 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        amounts[3] = 5000 * 10 ** 6;
        amounts[4] = 10000 * 10 ** 6;

        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(investor);
            stableToken.approve(address(factory), amounts[i]);
            vm.prank(investor);
            factory.invest(property, amounts[i]);
        }

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertTrue(token.balanceOf(investor) > 0);
    }

    function testPlatformFeeUpdate() public {
        uint256 newFee = 1000;
        vm.prank(admin);
        factory.setPlatformFeeBps(newFee);
        assertEq(factory.platformFeeBps(), newFee);

        vm.prank(admin);
        factory.setPlatformFeeBps(500);
    }

    function testPlatformFeeCannotExceedMax() public {
        uint256 invalidFee = 3000;
        vm.expectRevert("FEE_TOO_HIGH");
        vm.prank(admin);
        factory.setPlatformFeeBps(invalidFee);
    }

    function testFiatInvestment() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        uint256 amount = 10000 * 10 ** 6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_1"));
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(backendSigner);
        factory.processFiatInvestment(investor, property, amount, paymentId, deadline);

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertTrue(token.balanceOf(investor) > 0);
        assertTrue(factory.processedPayments(paymentId));
    }

    function testFiatInvestmentFailsWithDuplicatePayment() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        uint256 amount = 10000 * 10 ** 6;
        bytes32 paymentId = keccak256(abi.encodePacked("payment_duplicate"));
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(backendSigner);
        factory.processFiatInvestment(investor, property, amount, paymentId, deadline);

        vm.expectRevert("ALREADY_PROCESSED");
        vm.prank(backendSigner);
        factory.processFiatInvestment(investor, property, amount, paymentId, deadline);
    }

    function testInvestFailsWhenProtocolPaused() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        vm.prank(emergencyAdmin);
        accessController.pause();

        uint256 investAmount = 1000 * 10 ** 6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);

        vm.expectRevert("PAUSED");
        vm.prank(investor);
        factory.invest(property, investAmount);

        vm.prank(emergencyAdmin);
        accessController.unpause();
    }

    function testInvestFailsIfBlacklisted() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", propertyAdmin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        vm.prank(securityGuard);
        accessController.blacklist(investor);

        uint256 investAmount = 1000 * 10 ** 6;
        vm.prank(investor);
        stableToken.approve(address(factory), investAmount);

        vm.expectRevert("BLACKLISTED");
        vm.prank(investor);
        factory.invest(property, investAmount);

        vm.prank(securityGuard);
        accessController.unblacklist(investor);
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
