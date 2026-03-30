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

    modifier onlyFactory() {
        require(msg.sender == factory, "NOT_FACTORY");
        _;
    }

    constructor(address factory_, address router_) {
        require(factory_ != address(0), "INVALID_FACTORY");
        require(router_ != address(0), "INVALID_ROUTER");
        factory = factory_;
        router = router_;
    }

    function createPropertyToken(
        string memory name,
        string memory symbol,
        address admin,
        address owner
    ) external override onlyFactory returns (address) {
        require(bytes(name).length > 0, "INVALID_NAME");
        require(bytes(symbol).length > 0, "INVALID_SYMBOL");
        require(admin != address(0), "INVALID_ADMIN");
        require(owner != address(0), "INVALID_OWNER");

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