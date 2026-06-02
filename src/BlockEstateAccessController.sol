// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IBlockEstateAccessController} from "./interfaces/IBlockEstateAccessController.sol";
import {IBlockEstateRouter} from "./interfaces/IBlockEstateRouter.sol";
import {BlockEstateConfig} from "./BlockEstateConfig.sol";

/**
 * @title BlockEstateAccessControl
 * @dev Central contract for roles, KYC, blacklist and protocol pause.
 */
contract BlockEstateAccessControl is
    IBlockEstateAccessController,
    AccessControlDefaultAdminRules,
    Pausable,
    ReentrancyGuard,
    BlockEstateConfig
{
    uint256 public sponsorAmount;
    uint256 public dailySponsorCap;
    mapping(address => mapping(uint256 => uint256)) public sponsorUsedByDay;

    mapping(address => bool) private _kycApproved;
    mapping(address => bool) private _blacklisted;
    mapping(address => bool) private _sponsoredOnce;

    // Events for compliance
    event KYCApproved(address indexed user, address indexed approver);
    event KYCRevoked(address indexed user, address indexed revoker);
    event Blacklisted(address indexed user, address indexed executor);
    event Unblacklisted(address indexed user, address indexed executor);
    event ProtocolPaused(address indexed executor);
    event ProtocolUnpaused(address indexed executor);
    event SponsorAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event SponsorUsed(address indexed user, uint256 amount, uint256 dailyUsed);

    constructor() AccessControlDefaultAdminRules(3 days, msg.sender) {
        sponsorAmount = 0.00025 ether;
        dailySponsorCap = 0.01 ether;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOT_ADMIN");
        _;
    }

    modifier onlyTreasury() {
        require(hasRole(_ROLE_TREASURY_OPERATOR, msg.sender), "NOT_TREASURY");
        _;
    }

    modifier onlyCompliance() {
        require(hasRole(_ROLE_COMPLIANCE_OFFICER, msg.sender), "NOT_COMPLIANCE");
        _;
    }

    modifier onlySecurity() {
        require(hasRole(_ROLE_SECURITY_GUARD, msg.sender), "NOT_SECURITY");
        _;
    }

    modifier onlyEmergency() {
        require(hasRole(_ROLE_EMERGENCY_ADMIN, msg.sender), "NOT_EMERGENCY");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE VALIDATION (EXTERNAL)
    //////////////////////////////////////////////////////////////*/

    function enforceAdmin(address account) external view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, account), "NOT_ADMIN");
    }

    function enforceFundsManager(address account) external view override {
        require(hasRole(_ROLE_TREASURY_OPERATOR, account), "NOT_TREASURY");
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE CONSTANTS (Public getters)
    //////////////////////////////////////////////////////////////*/

    function ROLE_SECURITY_GUARD() public pure returns (bytes32) {
        return _ROLE_SECURITY_GUARD;
    }

    function ROLE_TREASURY_OPERATOR() public pure returns (bytes32) {
        return _ROLE_TREASURY_OPERATOR;
    }

    function ROLE_COMPLIANCE_OFFICER() public pure returns (bytes32) {
        return _ROLE_COMPLIANCE_OFFICER;
    }

    function ROLE_EMERGENCY_ADMIN() public pure returns (bytes32) {
        return _ROLE_EMERGENCY_ADMIN;
    }

    function ROLE_BACKEND_SIGNER() public pure returns (bytes32) {
        return _ROLE_BACKEND_SIGNER;
    }

    /*//////////////////////////////////////////////////////////////
                                KYC
    //////////////////////////////////////////////////////////////*/

    function approveKYC(address user) external onlyCompliance nonReentrant {
        require(!_kycApproved[user], "ALREADY_KYC");

        uint256 currentDay = block.timestamp / 1 days;

        // One-time gas sponsorship for new users with daily cap
        if (!_sponsoredOnce[user]) {
            _sponsoredOnce[user] = true;

            uint256 bal = user.balance;
            uint256 needed = 0;

            if (bal < sponsorAmount && sponsorAmount != 0) {
                needed = sponsorAmount - bal;

                // Check daily cap using day-based mapping
                uint256 dailyUsed = sponsorUsedByDay[msg.sender][currentDay];
                require(dailyUsed + needed <= dailySponsorCap, "DAILY_CAP_EXCEEDED");

                sponsorUsedByDay[msg.sender][currentDay] = dailyUsed + needed;

                (bool ok,) = user.call{value: needed}("");
                require(ok, "SPONSOR_FAIL");

                emit SponsorUsed(user, needed, dailyUsed + needed);
            }
        }

        _kycApproved[user] = true;
        emit KYCApproved(user, msg.sender);
    }

    function revokeKYC(address user) external onlyCompliance {
        require(_kycApproved[user], "NOT_KYC");
        _kycApproved[user] = false;
        emit KYCRevoked(user, msg.sender);
    }

    function isKYCApproved(address user) external view override returns (bool) {
        return _kycApproved[user];
    }

    function isBackendSigner(address account) external view returns (bool) {
        return hasRole(_ROLE_BACKEND_SIGNER, account);
    }

    /*//////////////////////////////////////////////////////////////
                            BLACKLIST
    //////////////////////////////////////////////////////////////*/

    function blacklist(address user) external onlySecurity {
        require(!_blacklisted[user], "ALREADY_BLACKLISTED");
        _blacklisted[user] = true;
        emit Blacklisted(user, msg.sender);
    }

    function unblacklist(address user) external onlySecurity {
        require(_blacklisted[user], "NOT_BLACKLISTED");
        _blacklisted[user] = false;
        emit Unblacklisted(user, msg.sender);
    }

    function isBlacklisted(address user) external view override returns (bool) {
        return _blacklisted[user];
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyEmergency {
        _pause();
        emit ProtocolPaused(msg.sender);
    }

    function unpause() external onlyEmergency {
        _unpause();
        emit ProtocolUnpaused(msg.sender);
    }

    function isProtocolPaused() external view override returns (bool) {
        return paused();
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIG
    //////////////////////////////////////////////////////////////*/

    function setSponsorAmount(uint256 newAmount) external onlyAdmin {
        require(newAmount <= MAX_SPONSOR_AMOUNT, "AMOUNT_TOO_HIGH");
        emit SponsorAmountUpdated(sponsorAmount, newAmount);
        sponsorAmount = newAmount;
    }

    function setDailySponsorCap(uint256 newCap) external onlyAdmin {
        dailySponsorCap = newCap;
    }

    /*//////////////////////////////////////////////////////////////
                            ROUTER SYNC
    //////////////////////////////////////////////////////////////*/

    function confirmAccessControllerUpdate(address router) external onlyAdmin {
        IBlockEstateRouter(router).confirmAccessControllerUpdate();
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function owner()
        public
        view
        override(IBlockEstateAccessController, AccessControlDefaultAdminRules)
        returns (address)
    {
        return super.owner();
    }

    receive() external payable {}
}
