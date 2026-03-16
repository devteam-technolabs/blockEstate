interface IBlockEstatePropertyIssuer {

    /// Deploys a new tokenized real estate asset
    function deployPropertyToken(
        uint256 totalSupply,
        address revenueToken,
        string calldata assetName,
        string calldata assetSymbol,
        address admin,
        address propertyOwner
    ) external returns (address token);
}