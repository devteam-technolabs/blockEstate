// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IBlockEstateAccessController.sol";
import "./BlockEstateRouter.sol";

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
      // Skip checks for minting and burning
      if (from == address(0) || to == address(0)) {
        super._update(from, to, amount);
        return;
      }

      IBlockEstateAccessController accessController =
      IBlockEstateAccessController(router.accessController());

      // Global protocol state check
      require(!accessController.isProtocolPaused(), "PROTOCOL_PAUSED");

      // Blacklist checks
      require(!accessController.isBlacklisted(from), "SENDER_BLACKLISTED");
      require(!accessController.isBlacklisted(to), "RECIPIENT_BLACKLISTED");

      // Compliance checks
      require(accessController.isKYCApproved(from), "SENDER_NOT_KYC");
      require(accessController.isKYCApproved(to), "RECIPIENT_NOT_KYC");

      super._update(from, to, amount);
    }

}