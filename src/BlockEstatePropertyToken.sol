// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {BlockEstateRouter} from "./BlockEstateRouter.sol";
import {BlockEstateRevenueDistributor} from "./BlockEstateRevenueDistributor.sol";
import {BlockEstateConfig} from "./BlockEstateConfig.sol";

/**
 * @title BlockEstatePropertyToken
 * @dev ERC20 representing fractional ownership of a property with supply cap.
 */
contract BlockEstatePropertyToken is ERC20, BlockEstateConfig {
    BlockEstateRouter public router;
    address public factory;

    address public admin;
    address public assetOwner;

    uint256 public maxSupply;
    uint256 public sharePrice;
    uint256 public totalRaised;
    bool public fundraisingClosed;
    PropertyStatus public status;

    event FundraisingClosed();
    event PropertyStatusUpdated(PropertyStatus indexed oldStatus, PropertyStatus indexed newStatus);
    event SharesMinted(address indexed to, uint256 amount, uint256 price);
    event AssetOwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyFactory() {
        require(msg.sender == factory, "ONLY_FACTORY");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == factory || msg.sender == admin || msg.sender == assetOwner, "NOT_AUTHORIZED");
        _;
    }

    constructor(
        address router_,
        address factory_,
        string memory name,
        string memory symbol,
        address admin_,
        address owner_,
        uint256 maxSupply_,
        uint256 sharePrice_
    ) ERC20(name, symbol) {
        require(maxSupply_ > 0, "INVALID_MAX_SUPPLY");
        require(sharePrice_ > 0, "INVALID_SHARE_PRICE");

        router = BlockEstateRouter(router_);
        factory = factory_;
        admin = admin_;
        assetOwner = owner_;
        maxSupply = maxSupply_;
        sharePrice = sharePrice_;
        status = PropertyStatus.FUNDRAISING;
    }

    function mint(address to, uint256 stableAmount) external onlyFactory returns (uint256) {
        require(!fundraisingClosed, "FUNDRAISING_CLOSED");
        require(status == PropertyStatus.FUNDRAISING, "NOT_FUNDRAISING");

        uint256 shares = (stableAmount * 1e18) / sharePrice;
        require(shares > 0, "INVALID_SHARE_AMOUNT");
        require(totalSupply() + shares <= maxSupply, "MAX_SUPPLY_EXCEEDED");

        totalRaised += stableAmount;
        _mint(to, shares);

        emit SharesMinted(to, shares, sharePrice);
        return shares;
    }

    function closeFundraising() external onlyAuthorized {
        require(!fundraisingClosed, "ALREADY_CLOSED");
        fundraisingClosed = true;
        status = PropertyStatus.ACTIVE;
        emit FundraisingClosed();
        emit PropertyStatusUpdated(PropertyStatus.FUNDRAISING, PropertyStatus.ACTIVE);
    }

    function updateStatus(PropertyStatus newStatus) external onlyAuthorized {
        require(newStatus != status, "SAME_STATUS");
        emit PropertyStatusUpdated(status, newStatus);
        status = newStatus;
    }

    function pauseProperty() external onlyAuthorized {
        require(status == PropertyStatus.ACTIVE, "NOT_ACTIVE");
        status = PropertyStatus.PAUSED;
        emit PropertyStatusUpdated(PropertyStatus.ACTIVE, PropertyStatus.PAUSED);
    }

    function unpauseProperty() external onlyAuthorized {
        require(status == PropertyStatus.PAUSED, "NOT_PAUSED");
        status = PropertyStatus.ACTIVE;
        emit PropertyStatusUpdated(PropertyStatus.PAUSED, PropertyStatus.ACTIVE);
    }

    function transferAssetOwnership(address newOwner) external onlyAuthorized {
        require(newOwner != address(0), "INVALID_OWNER");
        address oldOwner = assetOwner;
        assetOwner = newOwner;
        emit AssetOwnershipTransferred(oldOwner, newOwner);
    }

    function calculateShares(uint256 stableAmount) external view returns (uint256) {
        return (stableAmount * 1e18) / sharePrice;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        require(status != PropertyStatus.PAUSED, "PROPERTY_PAUSED");

        IBlockEstateAccessController ac = IBlockEstateAccessController(router.accessController());

        require(!ac.isProtocolPaused(), "PROTOCOL_PAUSED");
        require(!ac.isBlacklisted(from), "SENDER_BLACKLISTED");
        require(!ac.isBlacklisted(to), "RECIPIENT_BLACKLISTED");
        require(ac.isKYCApproved(from), "SENDER_NOT_KYC");
        require(ac.isKYCApproved(to), "RECIPIENT_NOT_KYC");

        // Get balances before transfer
        uint256 fromBalanceBefore = balanceOf(from);
        uint256 toBalanceBefore = balanceOf(to);

        // Execute the transfer
        super._update(from, to, amount);

        // Get balances after transfer
        uint256 fromBalanceAfter = balanceOf(from);
        uint256 toBalanceAfter = balanceOf(to);

        // Notify distributor with both before and after balances
        address distributor = router.revenueDistributor();
        if (distributor != address(0)) {
            BlockEstateRevenueDistributor(distributor)
                .updateOnTransfer(
                    address(this),
                    from,
                    to,
                    amount,
                    fromBalanceBefore,
                    toBalanceBefore,
                    fromBalanceAfter,
                    toBalanceAfter
                );
        }
    }
}
