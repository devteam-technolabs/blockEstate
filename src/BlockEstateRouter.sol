// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {BlockEstateConfig} from "./BlockEstateConfig.sol";

/**
 * @title BlockEstateRouter
 * @dev Stores core protocol addresses and allows controlled updates with timelock.
 * @dev NOTE: For production, consider using OpenZeppelin TimelockController with multisig for additional security.
 */
contract BlockEstateRouter is BlockEstateConfig {
    struct PendingChange {
        address target;
        uint64 timestamp;
        bool exists;
    }

    address public accessController;
    address public factory;
    address public treasury;
    address public stableToken;
    address public revenueDistributor;
    address public referralRewards;
    address public assetIssuance;

    mapping(bytes32 => PendingChange) public pendingChanges;

    event Updated(string indexed key, address value);
    event AccessControllerUpdated(address indexed oldController, address indexed newController);
    event ChangeScheduled(string indexed key, address indexed oldValue, address indexed newValue, uint256 executeTime);
    event ChangeCancelled(string indexed key);

    constructor(address _accessController) {
        require(_accessController != address(0), "INVALID_ACCESS_CONTROLLER");
        accessController = _accessController;
    }

    modifier onlyAdmin() {
        IBlockEstateAccessController(accessController).enforceAdmin(msg.sender);
        _;
    }

    modifier onlyTimelock() {
        IBlockEstateAccessController(accessController).enforceAdmin(msg.sender);
        _;
    }

    function _scheduleChange(string memory key, address newValue) internal {
        bytes32 changeId = keccak256(abi.encodePacked(key));
        require(!pendingChanges[changeId].exists, "CHANGE_PENDING");

        pendingChanges[changeId] =
            PendingChange({target: newValue, timestamp: uint64(block.timestamp + TIMELOCK_DELAY), exists: true});

        emit ChangeScheduled(key, address(0), newValue, block.timestamp + TIMELOCK_DELAY);
    }

    function _executeChange(string memory key, address newValue) internal {
        bytes32 changeId = keccak256(abi.encodePacked(key));
        PendingChange memory pending = pendingChanges[changeId];

        require(pending.exists, "NO_PENDING_CHANGE");
        require(pending.target == newValue, "VALUE_MISMATCH");
        require(block.timestamp >= pending.timestamp, "TIMELOCK_ACTIVE");

        delete pendingChanges[changeId];
    }

    function setFactory(address _factory) external onlyAdmin {
        require(_factory != address(0), "INVALID_FACTORY");
        _scheduleChange("FACTORY", _factory);
    }

    function executeSetFactory(address _factory) external onlyTimelock {
        _executeChange("FACTORY", _factory);
        factory = _factory;
        emit Updated("FACTORY", _factory);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "INVALID_TREASURY");
        _scheduleChange("TREASURY", _treasury);
    }

    function executeSetTreasury(address _treasury) external onlyTimelock {
        _executeChange("TREASURY", _treasury);
        treasury = _treasury;
        emit Updated("TREASURY", _treasury);
    }

    function setStableToken(address _token) external onlyAdmin {
        require(_token != address(0), "INVALID_STABLE_TOKEN");
        _scheduleChange("STABLE", _token);
    }

    function executeSetStableToken(address _token) external onlyTimelock {
        _executeChange("STABLE", _token);
        stableToken = _token;
        emit Updated("STABLE", _token);
    }

    function setRevenueDistributor(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_DISTRIBUTOR");
        _scheduleChange("REVENUE_DISTRIBUTOR", _addr);
    }

    function executeSetRevenueDistributor(address _addr) external onlyTimelock {
        _executeChange("REVENUE_DISTRIBUTOR", _addr);
        revenueDistributor = _addr;
        emit Updated("REVENUE_DISTRIBUTOR", _addr);
    }

    function setReferralRewards(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_REFERRAL");
        _scheduleChange("REFERRAL", _addr);
    }

    function executeSetReferralRewards(address _addr) external onlyTimelock {
        _executeChange("REFERRAL", _addr);
        referralRewards = _addr;
        emit Updated("REFERRAL", _addr);
    }

    function setAssetIssuance(address _addr) external onlyAdmin {
        require(_addr != address(0), "INVALID_ASSET_ISSUANCE");
        _scheduleChange("ASSET_ISSUANCE", _addr);
    }

    function executeSetAssetIssuance(address _addr) external onlyTimelock {
        _executeChange("ASSET_ISSUANCE", _addr);
        assetIssuance = _addr;
        emit Updated("ASSET_ISSUANCE", _addr);
    }

    function cancelPendingChange(string memory key) external onlyAdmin {
        bytes32 changeId = keccak256(abi.encodePacked(key));
        require(pendingChanges[changeId].exists, "NO_PENDING_CHANGE");
        delete pendingChanges[changeId];
        emit ChangeCancelled(key);
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
