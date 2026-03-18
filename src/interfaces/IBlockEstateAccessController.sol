// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IBlockEstateAccessController {

    /*//////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    function enforceAdmin(address account) external view;
    function enforceFundsManager(address account) external view;

    function owner() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            COMPLIANCE
    //////////////////////////////////////////////////////////////*/

    function isKYCApproved(address user) external view returns (bool);

    function isBlacklisted(address user) external view returns (bool);

    function isProtocolPaused() external view returns (bool);
}