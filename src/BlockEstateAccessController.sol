// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./interfaces/IBlockEstateAccessController.sol";
import "./interfaces/IBlockEstateRouter.sol";
import "./BlockEstateConfig.sol";

/**
 * @title BlockEstate Access Control
 *
 * @notice
 * Central authority managing:
 * - Roles
 * - KYC
 * - Blacklist
 * - Global pause
 */
contract BlockEstateAccessControl is
    IBlockEstateAccessController,
    AccessControlDefaultAdminRules,
    Pausable,
    BlockEstateConfig
{
    uint256 public sponsorAmount;

    mapping(address => bool) private _kycApproved;
    mapping(address => bool) private _blacklisted;
    mapping(address => bool) private _sponsoredOnce;

    constructor()
        AccessControlDefaultAdminRules(3 days, msg.sender)
    {
        sponsorAmount = 0.00025 ether;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOT_ADMIN");
        _;
    }

    modifier onlyTreasury() {
        require(hasRole(ROLE_TREASURY_OPERATOR, msg.sender), "NOT_TREASURY");
        _;
    }

    modifier onlyCompliance() {
        require(hasRole(ROLE_COMPLIANCE_OFFICER, msg.sender), "NOT_COMPLIANCE");
        _;
    }

    modifier onlySecurity() {
        require(hasRole(ROLE_SECURITY_GUARD, msg.sender), "NOT_SECURITY");
        _;
    }

    modifier onlyEmergency() {
        require(hasRole(ROLE_EMERGENCY_ADMIN, msg.sender), "NOT_EMERGENCY");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN VALIDATION (INTERFACE)
    //////////////////////////////////////////////////////////////*/

    function enforceAdmin(address account) external view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, account), "NOT_ADMIN");
    }

    function enforceFundsManager(address account) external view override {
        require(hasRole(ROLE_TREASURY_OPERATOR, account), "NOT_TREASURY");
    }

    /*//////////////////////////////////////////////////////////////
                            KYC
    //////////////////////////////////////////////////////////////*/

    function approveKYC(address user) external onlyCompliance {
        require(!_kycApproved[user], "ALREADY_KYC");

        if (!_sponsoredOnce[user]) {
            _sponsoredOnce[user] = true;

            uint256 bal = user.balance;

            if (bal < sponsorAmount && sponsorAmount != 0) {
                (bool ok, ) = user.call{value: sponsorAmount - bal}("");
                require(ok, "SPONSOR_FAIL");
            }
        }

        _kycApproved[user] = true;
    }

    function revokeKYC(address user) external onlyCompliance {
        require(_kycApproved[user], "NOT_KYC");
        _kycApproved[user] = false;
    }

    function isKYCApproved(address user)
        external
        view
        override
        returns (bool)
    {
        return _kycApproved[user];
    }

    /*//////////////////////////////////////////////////////////////
                            BLACKLIST
    //////////////////////////////////////////////////////////////*/

    function blacklist(address user) external onlySecurity {
        require(!_blacklisted[user], "ALREADY_BLACKLISTED");
        _blacklisted[user] = true;
    }

    function unblacklist(address user) external onlySecurity {
        require(_blacklisted[user], "NOT_BLACKLISTED");
        _blacklisted[user] = false;
    }

    function isBlacklisted(address user)
        external
        view
        override
        returns (bool)
    {
        return _blacklisted[user];
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyEmergency {
        _pause();
    }

    function unpause() external onlyEmergency {
        _unpause();
    }

    function isProtocolPaused()
        external
        view
        override
        returns (bool)
    {
        return paused();
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIG
    //////////////////////////////////////////////////////////////*/

    function setSponsorAmount(uint256 newAmount) external onlyAdmin {
        sponsorAmount = newAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            ROUTER SYNC
    //////////////////////////////////////////////////////////////*/

    function confirmAccessControllerUpdate(address router)
        external
        onlyAdmin
    {
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