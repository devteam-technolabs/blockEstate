// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./interfaces/IBlockEstateRouter.sol";
import "./interfaces/IBlockEstateAccessController.sol";
import "./BlockEstateTokenizationFactory.sol";

/**
 * @title BlockEstate Fiat Gateway Adapter
 *
 * @notice Bridges off-chain fiat payments to on-chain actions
 */
contract BlockEstateFiatGatewayAdapter {

    IBlockEstateRouter public router;
    BlockEstateTokenizationFactory public factory;

    address public backendSigner;

    event FiatProcessed(
        address indexed user,
        uint256 amount,
        bytes32 paymentId
    );

    constructor(address router_, address factory_, address signer_) {
        router = IBlockEstateRouter(router_);
        factory = BlockEstateTokenizationFactory(factory_);
        backendSigner = signer_;
    }

    modifier onlyBackend() {
        require(msg.sender == backendSigner, "NOT_BACKEND");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        FIAT → TOKEN FLOW
    //////////////////////////////////////////////////////////////*/

   function processFiatInvestment(
      address user,
      address property,
      uint256 amount,
      bytes32 paymentId
    ) external onlyBackend {

        factory.investFromFiat(property, user, amount);

        emit FiatProcessed(user, amount, paymentId);
    }

    function updateBackend(address newBackend) external {
        IBlockEstateAccessController ac =
            IBlockEstateAccessController(router.getAccessController());

        ac.enforceAdmin(msg.sender);

        backendSigner = newBackend;
    }
}