// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BlockEstatePropertyToken} from "./BlockEstatePropertyToken.sol";
import {IBlockEstateAssetIssuance} from "./interfaces/IBlockEstateAssetIssuance.sol";

/**
 * @title BlockEstateAssetIssuance
 * @dev Responsible for deploying new property token contracts via the factory.
 */
contract BlockEstateAssetIssuance is IBlockEstateAssetIssuance {

    address public factory;
    address public router;

    constructor(address factory_, address router_) {
        factory = factory_;
        router = router_;
    }

    function createPropertyToken(
        string memory name,
        string memory symbol,
        address admin,
        address owner
    ) external override returns (address) {
        require(msg.sender == factory, "NOT_FACTORY");

        return address(
            new BlockEstatePropertyToken(
                router,
                factory,
                name,
                symbol,
                admin,
                owner
            )
        );
    }
}