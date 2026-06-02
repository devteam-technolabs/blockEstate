// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../../src/BlockEstateAccessController.sol";
import "../../src/BlockEstateRouter.sol";
import "../../src/BlockEstateTokenizationFactory.sol";
import "../../src/BlockEstateAssetIssuance.sol";
import "../../src/BlockEstatePropertyToken.sol";
import "../../src/BlockEstateRevenueDistributor.sol";
import "../../src/referral/BlockEstateReferralRewards.sol";

contract BlockEstateIntegrationTest is Test {
    BlockEstateAccessControl public accessController;
    BlockEstateRouter public router;
    BlockEstateTokenizationFactory public factory;
    BlockEstateAssetIssuance public assetIssuance;
    BlockEstateRevenueDistributor public revenueDistributor;
    BlockEstateReferralRewards public referralRewards;
    MockERC20 public stableToken;

    address public admin;
    address public complianceOfficer = address(0x2);
    address public securityGuard = address(0x3);
    address public emergencyAdmin = address(0x4);
    address public treasury = address(0x5);
    address public backendSigner;
    address public investor1 = address(0x6);
    address public investor2 = address(0x7);
    address public propertyOwner = address(0x8);
    address public referrer = address(0x9);

    uint256 internal constant BACKEND_SIGNER_PRIVATE_KEY = 0x4;

    function setUp() public {
        admin = address(this);
        backendSigner = vm.addr(BACKEND_SIGNER_PRIVATE_KEY);

        uint256 ethAmount = 1 ether;
        vm.deal(complianceOfficer, ethAmount);
        vm.deal(securityGuard, ethAmount);
        vm.deal(emergencyAdmin, ethAmount);
        vm.deal(treasury, ethAmount);
        vm.deal(backendSigner, ethAmount);
        vm.deal(investor1, ethAmount);
        vm.deal(investor2, ethAmount);
        vm.deal(propertyOwner, ethAmount);
        vm.deal(referrer, ethAmount);

        accessController = new BlockEstateAccessControl();

        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_COMPLIANCE_OFFICER(), complianceOfficer);
        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_SECURITY_GUARD(), securityGuard);
        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_EMERGENCY_ADMIN(), emergencyAdmin);
        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_TREASURY_OPERATOR(), treasury);
        vm.prank(admin);
        accessController.grantRole(accessController.ROLE_BACKEND_SIGNER(), backendSigner);

        router = new BlockEstateRouter(address(accessController));

        stableToken = new MockERC20("USD Coin", "USDC", 6);

        factory = new BlockEstateTokenizationFactory(address(router));

        assetIssuance = new BlockEstateAssetIssuance(address(factory), address(router));

        revenueDistributor = new BlockEstateRevenueDistributor(address(router));

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

        stableToken.mint(investor1, 1000000 * 10 ** 6);
        stableToken.mint(investor2, 1000000 * 10 ** 6);
        stableToken.mint(propertyOwner, 1000000 * 10 ** 6);
        stableToken.mint(referrer, 1000000 * 10 ** 6);
        stableToken.mint(address(referralRewards), 100000 * 10 ** 6);

        vm.prank(complianceOfficer);
        accessController.approveKYC(investor1);
        vm.prank(complianceOfficer);
        accessController.approveKYC(investor2);
        vm.prank(complianceOfficer);
        accessController.approveKYC(propertyOwner);
        vm.prank(complianceOfficer);
        accessController.approveKYC(referrer);
    }

    function testCompleteWorkflow() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Luxury Villa", "VILLA", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        assertTrue(factory.isValidProperty(property));
        assertEq(factory.totalProperties(), 1);

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertEq(token.name(), "Luxury Villa");
        assertEq(token.symbol(), "VILLA");
        assertEq(token.maxSupply(), maxSupply);
        assertEq(token.sharePrice(), sharePrice);
        assertEq(uint256(token.status()), 0);

        vm.prank(investor1);
        stableToken.approve(address(factory), 10000 * 10 ** 6);

        vm.prank(investor1);
        factory.invest(property, 10000 * 10 ** 6);

        uint256 fee = (10000 * 10 ** 6 * 500) / 10000;
        uint256 net = 10000 * 10 ** 6 - fee;
        uint256 expectedNetShares = (net * 1e18) / sharePrice;

        assertEq(token.balanceOf(investor1), expectedNetShares);

        vm.prank(investor2);
        stableToken.approve(address(factory), 5000 * 10 ** 6);

        vm.prank(investor2);
        factory.invest(property, 5000 * 10 ** 6);

        uint256 revenueAmount = 1000 * 10 ** 6;
        vm.prank(propertyOwner);
        stableToken.approve(address(revenueDistributor), revenueAmount);

        vm.prank(propertyOwner);
        revenueDistributor.depositRevenue(property, revenueAmount);

        assertTrue(revenueDistributor.accRevenuePerToken(property) > 0);
        assertEq(revenueDistributor.propertyEscrow(property), revenueAmount);

        uint256 investor1BalanceBefore = stableToken.balanceOf(investor1);
        uint256 investor2BalanceBefore = stableToken.balanceOf(investor2);

        vm.prank(investor1);
        revenueDistributor.claim(property);

        vm.prank(investor2);
        revenueDistributor.claim(property);

        assertTrue(stableToken.balanceOf(investor1) > investor1BalanceBefore);
        assertTrue(stableToken.balanceOf(investor2) > investor2BalanceBefore);
    }

    function testReferralWorkflow() public {
        vm.prank(investor1);
        referralRewards.setReferrer(referrer);

        assertEq(referralRewards.referrerOf(investor1), referrer);

        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;

        vm.prank(admin);
        address property = factory.createProperty(
            "Test Property", "TEST", admin, propertyOwner, maxSupply, sharePrice, targetRaise * 2, targetRaise
        );

        uint256 referrerRewardsBefore = referralRewards.rewards(referrer);
        uint256 totalOutstandingBefore = referralRewards.totalRewardsOutstanding();

        vm.prank(investor1);
        stableToken.approve(address(factory), 10000 * 10 ** 6);

        vm.prank(investor1);
        factory.invest(property, 10000 * 10 ** 6);

        assertTrue(referralRewards.rewards(referrer) > referrerRewardsBefore);
        assertTrue(referralRewards.totalRewardsOutstanding() > totalOutstandingBefore);

        uint256 claimableReward = referralRewards.pendingReward(referrer);
        assertTrue(claimableReward > 0);

        uint256 referrerBalanceBefore = stableToken.balanceOf(referrer);

        vm.prank(referrer);
        referralRewards.claim();

        assertTrue(stableToken.balanceOf(referrer) > referrerBalanceBefore);
        assertEq(referralRewards.rewards(referrer), 0);
    }

    function testPropertyLifecycle() public {
        uint256 maxSupply = 1000000 * 10 ** 18; // Increased max supply
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Lifecycle Test", "LIFE", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertEq(uint256(token.status()), 0);

        uint256 investAmount = 5000 * 10 ** 6;
        vm.prank(investor1);
        stableToken.approve(address(factory), investAmount);
        vm.prank(investor1);
        factory.invest(property, investAmount);

        vm.prank(propertyOwner);
        token.closeFundraising();
        assertTrue(token.fundraisingClosed());
        assertEq(uint256(token.status()), 1);

        vm.prank(propertyOwner);
        token.pauseProperty();
        assertEq(uint256(token.status()), 4);

        vm.prank(propertyOwner);
        token.unpauseProperty();
        assertEq(uint256(token.status()), 1);
    }

    function testTransferWithRewards() public {
        uint256 maxSupply = 1000000 * 10 ** 18;
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Transfer Test", "TRANS", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);

        // Make investment
        vm.prank(investor1);
        stableToken.approve(address(factory), 200000 * 10 ** 6);
        vm.prank(investor1);
        factory.invest(property, 200000 * 10 ** 6);

        // Get initial balances
        uint256 investor1InitialBalance = stableToken.balanceOf(investor1);
        uint256 investor2InitialBalance = stableToken.balanceOf(investor2);

        // Deposit revenue (only investor1 owns shares at this point)
        vm.prank(propertyOwner);
        stableToken.approve(address(revenueDistributor), 200000 * 10 ** 6);
        vm.prank(propertyOwner);
        revenueDistributor.depositRevenue(property, 200000 * 10 ** 6);

        // Transfer half of investor1's shares to investor2
        uint256 investor1SharesBefore = token.balanceOf(investor1);
        uint256 transferAmount = investor1SharesBefore / 2;

        vm.prank(investor1);
        token.transfer(investor2, transferAmount);

        // Investor2 claims - should get NO_REWARD because revenue was deposited before they owned shares
        vm.prank(investor2);
        vm.expectRevert("NO_REWARD");
        revenueDistributor.claim(property);

        // Investor1 claims - should get all the revenue
        vm.prank(investor1);
        revenueDistributor.claim(property);

        // Verify investor1 received all rewards
        assertTrue(stableToken.balanceOf(investor1) > investor1InitialBalance);
        // Investor2 balance should remain unchanged
        assertEq(stableToken.balanceOf(investor2), investor2InitialBalance);
        assertTrue(token.balanceOf(investor2) > 0);
    }

    function testAdminFunctions() public {
        vm.prank(admin);
        factory.setPlatformFeeBps(1000);
        assertEq(factory.platformFeeBps(), 1000);

        vm.prank(admin);
        factory.setPlatformFeeBps(500);

        // Create a random token for testing
        MockERC20 randomToken = new MockERC20("Random", "RND", 18);
        randomToken.mint(address(factory), 10000 * 10 ** 18);

        vm.prank(admin);
        factory.emergencyWithdrawERC20(address(randomToken), admin, 10000 * 10 ** 18);

        vm.expectRevert("CANNOT_WITHDRAW_STABLE_TOKEN");
        vm.prank(admin);
        factory.emergencyWithdrawERC20(address(stableToken), admin, 1000 * 10 ** 6);
    }

    function testPauseFunctionality() public {
        uint256 maxSupply = 1000000 * 10 ** 18; // Increased max supply
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Pause Test", "PAUSE", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);

        vm.prank(investor1);
        stableToken.approve(address(factory), 10000 * 10 ** 6);
        vm.prank(investor1);
        factory.invest(property, 10000 * 10 ** 6);

        vm.prank(emergencyAdmin);
        accessController.pause();

        // Investment should revert with PAUSED
        vm.prank(investor2);
        stableToken.approve(address(factory), 5000 * 10 ** 6);

        vm.expectRevert("PAUSED");
        vm.prank(investor2);
        factory.invest(property, 5000 * 10 ** 6);

        // Transfer should revert with PROTOCOL_PAUSED
        vm.expectRevert("PROTOCOL_PAUSED");
        vm.prank(investor1);
        token.transfer(investor2, 100);

        vm.prank(emergencyAdmin);
        accessController.unpause();

        // Now investment should work
        vm.prank(investor2);
        stableToken.approve(address(factory), 5000 * 10 ** 6);
        vm.prank(investor2);
        factory.invest(property, 5000 * 10 ** 6);

        assertTrue(token.balanceOf(investor2) > 0);
    }

    function testBlacklistFunctionality() public {
        uint256 maxSupply = 1000000 * 10 ** 18; // Increased max supply
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Blacklist Test", "BLACK", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);

        vm.prank(investor1);
        stableToken.approve(address(factory), 10000 * 10 ** 6);
        vm.prank(investor1);
        factory.invest(property, 10000 * 10 ** 6);

        vm.prank(securityGuard);
        accessController.blacklist(investor1);

        vm.expectRevert("SENDER_BLACKLISTED");
        vm.prank(investor1);
        token.transfer(investor2, 100);

        // Investment should fail with BLACKLISTED
        vm.prank(investor1);
        stableToken.approve(address(factory), 5000 * 10 ** 6);

        vm.expectRevert("BLACKLISTED");
        vm.prank(investor1);
        factory.invest(property, 5000 * 10 ** 6);

        vm.prank(securityGuard);
        accessController.unblacklist(investor1);

        vm.prank(investor1);
        token.transfer(investor2, 100);
        assertTrue(token.balanceOf(investor2) > 0);
    }

    function testMultipleProperties() public {
        uint256 maxSupply = 1000000 * 10 ** 18; // Increased max supply
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        address[] memory properties = new address[](3);
        string[] memory names = new string[](3);
        names[0] = "Property A";
        names[1] = "Property B";
        names[2] = "Property C";

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(admin);
            properties[i] = factory.createProperty(
                names[i],
                string(abi.encodePacked("P", vm.toString(i + 1))),
                admin,
                propertyOwner,
                maxSupply,
                sharePrice,
                valuation,
                targetRaise
            );
        }

        assertEq(factory.totalProperties(), 3);

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(factory.isValidProperty(properties[i]));
            BlockEstatePropertyToken token = BlockEstatePropertyToken(properties[i]);
            assertEq(token.name(), names[i]);
        }

        vm.prank(investor1);
        stableToken.approve(address(factory), 30000 * 10 ** 6);

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(investor1);
            factory.invest(properties[i], 10000 * 10 ** 6);

            BlockEstatePropertyToken token = BlockEstatePropertyToken(properties[i]);
            assertTrue(token.balanceOf(investor1) > 0);
        }
    }

    function testAssetOwnershipTransfer() public {
        uint256 maxSupply = 1000000 * 10 ** 18; // Increased max supply
        uint256 sharePrice = 1 * 10 ** 6;
        uint256 targetRaise = (maxSupply * sharePrice) / 1e18;
        uint256 valuation = targetRaise * 2;

        vm.prank(admin);
        address property = factory.createProperty(
            "Ownership Test", "OWN", admin, propertyOwner, maxSupply, sharePrice, valuation, targetRaise
        );

        BlockEstatePropertyToken token = BlockEstatePropertyToken(property);
        assertEq(token.assetOwner(), propertyOwner);

        address newOwner = address(0x999);
        vm.prank(propertyOwner);
        token.transferAssetOwnership(newOwner);

        assertEq(token.assetOwner(), newOwner);

        vm.expectRevert("NOT_AUTHORIZED");
        vm.prank(propertyOwner);
        token.closeFundraising();

        vm.prank(newOwner);
        token.closeFundraising();
        assertTrue(token.fundraisingClosed());
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
