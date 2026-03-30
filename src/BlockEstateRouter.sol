// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";

/**
 * @title BlockEstateRouter
 * @dev Stores core protocol addresses and allows controlled updates.
 */
contract BlockEstateRouter {

    address public accessController;
    address public factory;
    address public treasury;
    address public stableToken;
    address public revenueDistributor;
    address public referralRewards;
    address public assetIssuance;

    event Updated(string indexed key, address value);
    event AccessControllerUpdated(address indexed oldController, address indexed newController);

    constructor(address _accessController) {
        require(_accessController != address(0), "INVALID_ACCESS_CONTROLLER");
        accessController = _accessController;
    }

    modifier onlyAdmin() {
        IBlockEstateAccessController(accessController).enforceAdmin(msg.sender);
        _;
    }

    function setFactory(address _factory) external onlyAdmin {
        require(_factory != address(0), "INVALID_FACTORY");
        factory = _factory;
        emit Updated("FACTORY", _factory);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "INVALID_TREASURY");
        treasury = _treasury;
        emit Updated("TREASURY", _treasury);
    }

    function setStableToken(address _token) external onlyAdmin {
        require(_token != address(0), "INVALID_STABLE_TOKEN");
        stableToken = _token;
        emit Updated("STABLE", _token);
    }

    function setRevenueDistributor(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_DISTRIBUTOR");
        revenueDistributor = _addr;
        emit Updated("REVENUE_DISTRIBUTOR", _addr);
    }

    function setReferralRewards(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_REFERRAL");
        referralRewards = _addr;
        emit Updated("REFERRAL", _addr);
    }

    function setAssetIssuance(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_ASSET_ISSUANCE");
        assetIssuance = _addr;
        emit Updated("ASSET_ISSUANCE", _addr);
    }

    function setAccessController(address newAccessController) external onlyAdmin {
        require(newAccessController != address(0), "INVALID_ACCESS_CONTROLLER");
        address oldController = accessController;
        accessController = newAccessController;
        emit AccessControllerUpdated(oldController, newAccessController);
    }

    function confirmAccessControllerUpdate() external view {
        require(msg.sender == accessController, "NOT_ACCESS_CONTROLLER");
    }

    function getAccessController() external view returns (address) {
        return accessController;
    }
}