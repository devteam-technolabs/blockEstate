// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./interfaces/IBlockEstateAccessController.sol";

contract BlockEstateRouter {

    address public accessController;
    address public factory;
    address public treasury;
    address public stableToken;

    event Updated(string indexed key, address value);

    constructor(address _accessController) {
        accessController = _accessController;
    }

    modifier onlyAdmin() {
        IBlockEstateAccessController(accessController).enforceAdmin(msg.sender);
        _;
    }

    function setFactory(address _factory) external onlyAdmin {
        factory = _factory;
        emit Updated("FACTORY", _factory);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        treasury = _treasury;
        emit Updated("TREASURY", _treasury);
    }

    function setStableToken(address _token) external onlyAdmin {
        stableToken = _token;
        emit Updated("STABLE", _token);
    }

    function confirmAccessControllerUpdate() external view {
        require(msg.sender == accessController, "NOT_ACCESS_CONTROLLER");
    }

    function getAccessController() external view returns (address) {
        return accessController;
    }
}