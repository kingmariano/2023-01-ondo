// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

/// @notice Minimal mock for the CTokenOracle interface used by OndoPriceOracleV2.
///         Returns a fixed price for any cToken address, covering the COMPOUND oracle path.
contract MockCTokenOracle {
    uint256 public constant PRICE = 1e18; // $1 in Compound oracle format (18 decimals mantissa)

    function getUnderlyingPrice(address /*cToken*/) external pure returns (uint256) {
        return PRICE;
    }
}
