// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

/// @notice Minimal ERC20 stub exposing only decimals() — used by MockFToken's underlying
///         so OndoPriceOracleV2._setFTokenToChainlinkOracle can compute scaleFactor.
contract MockERC20Decimals {
    uint8 private _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
