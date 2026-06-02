// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Script.sol";
import "../src/BlockEstateAccessController.sol";
import "../src/BlockEstateRouter.sol";
import "../src/BlockEstateRevenueDistributor.sol";
import "../src/referral/BlockEstateReferralRewards.sol";
import "../src/BlockEstateTokenizationFactory.sol";
import "../src/BlockEstateAssetIssuance.sol";

contract DeployBlockEstate is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address treasury = vm.envAddress("TREASURY");
        address stableToken = vm.envAddress("STABLE_TOKEN");
        address admin = vm.envOr("ADMIN", deployer);
        address complianceOfficer = vm.envAddress("COMPLIANCE_OFFICER");
        address securityGuard = vm.envAddress("SECURITY_GUARD");
        address emergencyAdmin = vm.envAddress("EMERGENCY_ADMIN");
        address backendSigner = vm.envAddress("BACKEND_SIGNER");

        vm.startBroadcast(deployerPrivateKey);

        BlockEstateAccessControl accessController = new BlockEstateAccessControl();
        BlockEstateRouter router = new BlockEstateRouter(address(accessController));
        BlockEstateRevenueDistributor revenueDistributor = new BlockEstateRevenueDistributor(address(router));
        BlockEstateReferralRewards referralRewards = new BlockEstateReferralRewards(address(router));
        BlockEstateTokenizationFactory factory = new BlockEstateTokenizationFactory(address(router));
        BlockEstateAssetIssuance assetIssuance = new BlockEstateAssetIssuance(address(factory), address(router));

        if (admin != deployer) {
            accessController.beginDefaultAdminTransfer(admin);
        }

        accessController.grantRole(accessController.ROLE_COMPLIANCE_OFFICER(), complianceOfficer);
        accessController.grantRole(accessController.ROLE_SECURITY_GUARD(), securityGuard);
        accessController.grantRole(accessController.ROLE_EMERGENCY_ADMIN(), emergencyAdmin);
        accessController.grantRole(accessController.ROLE_BACKEND_SIGNER(), backendSigner);
        accessController.grantRole(accessController.ROLE_TREASURY_OPERATOR(), treasury);

        router.setFactory(address(factory));
        router.setTreasury(treasury);
        router.setStableToken(stableToken);
        router.setRevenueDistributor(address(revenueDistributor));
        router.setReferralRewards(address(referralRewards));
        router.setAssetIssuance(address(assetIssuance));

        vm.stopBroadcast();
    }
}

contract ExecuteRouterChanges is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");

        address factory = vm.envAddress("FACTORY_ADDRESS");
        address treasury = vm.envAddress("TREASURY");
        address stableToken = vm.envAddress("STABLE_TOKEN");
        address revenueDistributor = vm.envAddress("REVENUE_DISTRIBUTOR");
        address referralRewards = vm.envAddress("REFERRAL_REWARDS");
        address assetIssuance = vm.envAddress("ASSET_ISSUANCE");

        vm.startBroadcast(deployerPrivateKey);

        BlockEstateRouter router = BlockEstateRouter(payable(routerAddress));

        router.executeSetFactory(factory);
        router.executeSetTreasury(treasury);
        router.executeSetStableToken(stableToken);
        router.executeSetRevenueDistributor(revenueDistributor);
        router.executeSetReferralRewards(referralRewards);
        router.executeSetAssetIssuance(assetIssuance);

        vm.stopBroadcast();
    }
}

contract AcceptAdminRole is Script {
    function run() external {
        uint256 newAdminPrivateKey = vm.envUint("PRIVATE_KEY");
        address accessControllerAddress = vm.envAddress("ACCESS_CONTROLLER_ADDRESS");

        vm.startBroadcast(newAdminPrivateKey);

        BlockEstateAccessControl accessController = BlockEstateAccessControl(payable(accessControllerAddress));
        accessController.acceptDefaultAdminTransfer();

        vm.stopBroadcast();
    }
}

contract VerifyDeployment is Script {
    function run() external view {
        address accessControllerAddress = vm.envAddress("ACCESS_CONTROLLER_ADDRESS");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");

        BlockEstateAccessControl accessController = BlockEstateAccessControl(payable(accessControllerAddress));
        BlockEstateRouter router = BlockEstateRouter(payable(routerAddress));
        BlockEstateTokenizationFactory factory = BlockEstateTokenizationFactory(factoryAddress);

        console.log("AccessController owner:", accessController.owner());
        console.log("Router factory:", router.factory());
        console.log("Router treasury:", router.treasury());
        console.log("Router stableToken:", router.stableToken());
        console.log("Factory router:", address(factory.router()));
        console.log("Factory platformFeeBps:", factory.platformFeeBps());
    }
}
