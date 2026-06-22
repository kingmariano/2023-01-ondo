// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {SelectorStorage} from "../SelectorStorage.sol";

import "contracts/lending/OndoPriceOracleV2.sol";

import {IOndoPriceOracleV2} from "contracts/lending/IOndoPriceOracleV2.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";
import {MockFToken} from "../mocks/MockFToken.sol";

abstract contract OndoPriceOracleV2Targets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// @notice Shortcut: exercises the price-cap branch in getUnderlyingPrice (line ~114)
    ///         Sets a price cap for cTokenDelegate fToken then reads price.
    ///         Requires: OracleType.MANUAL already set in Setup for cTokenDelegate
    function shortcut_priceCapPath(uint256 cap) public updateGhosts {
        address fToken = address(cTokenDelegate);
        // Clamp cap to non-zero
        if (cap == 0) cap = 1;
        // Set price cap (owner = address(this) as admin)
        ondoPriceOracleV2.setPriceCap(fToken, cap);
        // Read price — will apply cap if cap < price
        ondoPriceOracleV2.getUnderlyingPrice(fToken);
        // Reset cap to 0 to not interfere with other tests
        ondoPriceOracleV2.setPriceCap(fToken, 0);
    }

    // === GROUP B: COMPOUND oracle path handler ===

    /// @notice Exercises the COMPOUND oracle path in getUnderlyingPrice.
    ///         fTokenCompound is wired to OracleType.COMPOUND with cCashDelegate as cToken.
    ///         mockCTokenOracle returns a fixed price, so this will not revert.
    function shortcut_compoundOraclePath() public updateGhosts {
        ondoPriceOracleV2.getUnderlyingPrice(address(fTokenCompound));
    }

    // === GROUP B: CHAINLINK oracle path handler ===

    /// @notice Exercises the CHAINLINK oracle path in getUnderlyingPrice.
    ///         fTokenChainlink is wired to OracleType.CHAINLINK with the MockAggregatorV3.
    ///         The mock returns updatedAt=block.timestamp so the staleness check passes.
    function shortcut_chainlinkOraclePath(int256 /*answer*/) public updateGhosts {
        ondoPriceOracleV2.getUnderlyingPrice(address(fTokenChainlink));
    }

    /// @notice Directly calls getChainlinkOraclePrice for fTokenChainlink.
    ///         Covers the getChainlinkOraclePrice function body (lines 280-300).
    function ondoPriceOracleV2_getChainlinkOraclePrice_clamped() public updateGhosts {
        ondoPriceOracleV2.getChainlinkOraclePrice(address(fTokenChainlink));
    }

    // === GROUP B: setFTokenToCToken clamped handler (emit coverage) ===

    /// @notice Clamped setFTokenToCToken: uses fTokenCompound + cCashDelegate so
    ///         _setFTokenToCToken succeeds and the emit line is reached.
    ///         fTokenCompound is already set to OracleType.COMPOUND in Setup.
    function ondoPriceOracleV2_setFTokenToCToken_compound_clamped() public updateGhosts {
        // fTokenCompound.underlying() == address(0) == cCashDelegate.underlying() → passes equality check
        ondoPriceOracleV2.setFTokenToCToken(address(fTokenCompound), address(cCashDelegate));
    }

    // === GROUP B: setFTokenToChainlinkOracle clamped handler (emit coverage) ===

    /// @notice Clamped setFTokenToChainlinkOracle: uses fTokenChainlink + chainlinkOracle so
    ///         _setFTokenToChainlinkOracle succeeds and the emit line is reached.
    ///         fTokenChainlink is already set to OracleType.CHAINLINK in Setup.
    function ondoPriceOracleV2_setFTokenToChainlinkOracle_chainlink_clamped() public updateGhosts {
        ondoPriceOracleV2.setFTokenToChainlinkOracle(address(fTokenChainlink), address(chainlinkOracle));
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
