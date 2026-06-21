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

    /// @notice Shortcut: exercises the CHAINLINK oracle path in getUnderlyingPrice (line ~106)
    ///         Configures fToken with CHAINLINK oracle type and mock aggregator.
    ///         Requires: cTokenDelegate has underlying() that is a real ERC20 (NOT satisfied for bare delegate)
    ///         NOTE: This shortcut will revert because bare cTokenDelegate has no underlying().
    ///         Documented here for coverage-phase reference.
    function shortcut_chainlinkOraclePath(int256 answer) public updateGhosts {
        // Skip — bare delegate has no underlying(); would revert at setFTokenToChainlinkOracle
        // This shortcut is a placeholder for the coverage phase when markets are wired.
        // In that phase: setFTokenToOracleType(fToken, CHAINLINK), setFTokenToChainlinkOracle(fToken, oracle)
        // then getUnderlyingPrice(fToken).
        return;
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
