// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IPropertyTokenFactory {

    function recordFiatPurchase(
        uint256 propertyId,
        address investor,
        uint256 tokenAmount
    ) external;

    function distributeYield(
        uint256 propertyId,
        uint256 amount
    ) external;

    function referralClaimOpen(uint256 propertyId)
        external
        view
        returns (bool);

    function propertyTokenData(uint256 propertyId)
        external
        view
        returns (address token, address revenueToken);
}