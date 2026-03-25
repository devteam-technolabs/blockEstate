// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {BlockEstateRouter} from "./BlockEstateRouter.sol";
import {BlockEstateRevenueDistributor} from "./BlockEstateRevenueDistributor.sol";

/**
 * @title BlockEstatePropertyToken
 * @dev ERC20 representing fractional ownership of a property.
 */
contract BlockEstatePropertyToken is ERC20 {

    BlockEstateRouter public router;
    address public factory;

    address public admin;
    address public assetOwner;

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    constructor(
        address router_,
        address factory_,
        string memory name,
        string memory symbol,
        address admin_,
        address owner_
    ) ERC20(name, symbol) {
        router = BlockEstateRouter(router_);
        factory = factory_;
        admin = admin_;
        assetOwner = owner_;
    }

    function mint(address to, uint256 amount) external onlyFactory {
        _mint(to, amount);
    }
  
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {

        // Allow minting and burning without checks
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.accessController());

        require(!ac.isProtocolPaused(), "PROTOCOL_PAUSED");
        require(!ac.isBlacklisted(from), "SENDER_BLACKLISTED");
        require(!ac.isBlacklisted(to), "RECIPIENT_BLACKLISTED");
        require(ac.isKYCApproved(from), "SENDER_NOT_KYC");
        require(ac.isKYCApproved(to), "RECIPIENT_NOT_KYC");

        super._update(from, to, amount);

        // Notify distributor on balance changes
        address distributor = router.revenueDistributor();
        if (distributor != address(0)) {
            BlockEstateRevenueDistributor(distributor)
                .updateOnTransfer(address(this), from, to);
        }
    } 
}