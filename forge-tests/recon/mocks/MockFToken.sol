// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

/// @notice Minimal mock fToken used by the OndoPriceOracleV2 CHAINLINK oracle path.
///         _setFTokenToChainlinkOracle calls:
///           1. CTokenLike(fToken).underlying()  — must return a non-zero address with decimals()
///           2. IERC20Like(underlying).decimals() — used to compute scaleFactor
///         This mock hard-wires an underlying with a configurable decimal count.
contract MockFToken {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}
