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

        address treasury = vm.envAddress("TREASURY");
        address stableToken = vm.envAddress("STABLE_TOKEN");
        address backendSigner = vm.envAddress("BACKEND_SIGNER");

        vm.startBroadcast(deployerPrivateKey);

        // ACCESS CONTROL
        BlockEstateAccessControl access = new BlockEstateAccessControl();

        // Router 
        BlockEstateRouter router = new BlockEstateRouter(address(access));

        // CORE MODULES
        BlockEstateRevenueDistributor revenueDistributor =
            new BlockEstateRevenueDistributor(address(router));

        BlockEstateReferralRewards referralRewards =
            new BlockEstateReferralRewards(address(router));

        // FACTORY
        BlockEstateTokenizationFactory factory =
            new BlockEstateTokenizationFactory(address(router));

        // ASSET ISSUANCE
        BlockEstateAssetIssuance issuance =
            new BlockEstateAssetIssuance(address(factory), address(router));
                        
        // ROUTER CONFIGURATION
        router.setFactory(address(factory));
        router.setTreasury(treasury);
        router.setStableToken(stableToken);
        router.setRevenueDistributor(address(revenueDistributor));
        router.setReferralRewards(address(referralRewards));
        router.setAssetIssuance(address(issuance));

        // FACTORY CONFIG
        factory.setBackendSigner(backendSigner);

        vm.stopBroadcast();
    }
}