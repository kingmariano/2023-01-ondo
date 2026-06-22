// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {SelectorStorage} from "./SelectorStorage.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {

    // Tracks which function selector is currently executing
    // Using bytes4 selector instead of enum to avoid 256 member limit
    bytes4 public currentOperation;

    // -----------------------------------------------------------------------
    // Ghost accumulators (Phase 3A)
    // -----------------------------------------------------------------------

    /// @notice Monotonically-increasing epoch high-water mark.
    ///         Incremented by __after(); never decremented.
    uint256 public ghost_lastEpoch;

    /// @notice Canary booleans — set to true the first time the handler fires.
    bool public ghost_requestMintReached;
    bool public ghost_claimMintReached;
    bool public ghost_requestRedemptionReached;
    bool public ghost_completeRedemptionsReached;
    bool public ghost_setRateReached;
    bool public ghost_overrideRateReached;
    bool public ghost_transitionEpochReached;

    // -----------------------------------------------------------------------
    // Snapshot struct — populated by __before() and __after()
    // -----------------------------------------------------------------------
    struct Vars {
        // CASH token
        uint256 totalSupply;

        // Per-active-actor CASH balance
        uint256 cashBalanceActor;

        // CashManager epoch state
        uint256 currentEpoch;
        uint256 currentEpochStartTimestamp;
        uint256 epochDuration;

        // CashManager mint/redeem limits (current amounts consumed)
        uint256 currentMintAmount;
        uint256 currentRedeemAmount;

        // CashManager rate & pause state
        uint256 lastSetMintExchangeRate;
        bool paused;

        // Per-active-actor mint request in the current epoch
        uint256 mintRequestsActorCurrentEpoch;

        // Per-active-actor burn amount in the current epoch
        uint256 burnAmtActorCurrentEpoch;

        // totalBurned for the current epoch
        uint256 totalBurnedCurrentEpoch;

        // Exchange rate for the current epoch (may be 0 if not yet set)
        uint256 epochToExchangeRateCurrent;

        // Collateral balance of assetSender (address(this) in Setup)
        uint256 collateralBalanceAssetSender;

        // CashManager parameters
        uint256 mintFee;
        uint256 minimumDepositAmount;

        // OndoPriceOracleV2 price for cTokenDelegate
        uint256 oraclePriceCTokenDelegate;
        uint256 oraclePriceCCashDelegate;
        uint256 oraclePriceCapCTokenDelegate;
        uint256 oraclePriceCapCCashDelegate;
    }

    Vars internal _before;
    Vars internal _after;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    // Sets currentOperation to the function selector before execution
    modifier trackOp(bytes4 op) {
        currentOperation = op;
        __before();
        _;
        __after();
    }

    // -----------------------------------------------------------------------
    // Snapshot helpers
    // -----------------------------------------------------------------------

    function _snapshotVars() internal view returns (Vars memory v) {
        address actor = _getActor();

        v.totalSupply           = cashKYCSenderReceiver.totalSupply();
        v.cashBalanceActor      = cashKYCSenderReceiver.balanceOf(actor);

        v.currentEpoch              = cashManager.currentEpoch();
        v.currentEpochStartTimestamp = cashManager.currentEpochStartTimestamp();
        v.epochDuration             = cashManager.epochDuration();
        v.currentMintAmount         = cashManager.currentMintAmount();
        v.currentRedeemAmount       = cashManager.currentRedeemAmount();
        v.lastSetMintExchangeRate   = cashManager.lastSetMintExchangeRate();
        v.paused                    = cashManager.paused();

        uint256 ep = v.currentEpoch;
        v.mintRequestsActorCurrentEpoch  = cashManager.mintRequestsPerEpoch(ep, actor);
        (uint256 tb, uint256 burnAmt) = _getRedemptionInfo(ep, actor);
        v.totalBurnedCurrentEpoch        = tb;
        v.burnAmtActorCurrentEpoch       = burnAmt;
        v.epochToExchangeRateCurrent     = cashManager.epochToExchangeRate(ep);

        v.collateralBalanceAssetSender = _collateralBalanceOf(cashManager.assetSender());

        v.mintFee               = cashManager.mintFee();
        v.minimumDepositAmount  = cashManager.minimumDepositAmount();

        // Oracle prices (MANUAL path; read-only, won't revert)
        v.oraclePriceCTokenDelegate      = _safeGetPrice(address(cTokenDelegate));
        v.oraclePriceCCashDelegate       = _safeGetPrice(address(cCashDelegate));
        v.oraclePriceCapCTokenDelegate   = ondoPriceOracleV2.fTokenToUnderlyingPriceCap(address(cTokenDelegate));
        v.oraclePriceCapCCashDelegate    = ondoPriceOracleV2.fTokenToUnderlyingPriceCap(address(cCashDelegate));
    }

    /// @dev Returns (burnAmtActor, burnAmtActor) — we need two storage reads on
    ///      the redemptionInfoPerEpoch mapping. The outer mapping returns a struct
    ///      but Solidity can't do storage-to-memory copy for structs containing
    ///      nested mappings, so we call the public accessor for totalBurned
    ///      and addressToBurnAmt separately via helper.
    function _getRedemptionInfo(uint256 epoch, address actor)
        internal view
        returns (uint256 totalBurned, uint256 burnAmtActor)
    {
        // redemptionInfoPerEpoch is a public mapping; the auto-getter gives totalBurned
        // but NOT addressToBurnAmt (nested mapping).  We use getBurnedQuantity for the
        // per-actor field.
        (totalBurned,) = _redemptionTotalBurned(epoch);
        burnAmtActor = cashManager.getBurnedQuantity(epoch, actor);
    }

    function _redemptionTotalBurned(uint256 epoch)
        internal view
        returns (uint256 totalBurned, bool ok)
    {
        // The public getter for redemptionInfoPerEpoch returns only `totalBurned`
        // because addressToBurnAmt is a nested mapping and isn't auto-exposed.
        try cashManager.redemptionInfoPerEpoch(epoch) returns (uint256 tb) {
            return (tb, true);
        } catch {
            return (0, false);
        }
    }

    function _getTotalBurned(uint256 epoch) internal view returns (uint256) {
        (uint256 tb,) = _redemptionTotalBurned(epoch);
        return tb;
    }

    function _collateralBalanceOf(address who) internal view returns (uint256) {
        if (who == address(0)) return 0;
        try cashManager.collateral().balanceOf(who) returns (uint256 bal) {
            return bal;
        } catch {
            return 0;
        }
    }

    function _safeGetPrice(address fToken) internal view returns (uint256) {
        try ondoPriceOracleV2.getUnderlyingPrice(fToken) returns (uint256 p) {
            return p;
        } catch {
            return 0;
        }
    }

    // -----------------------------------------------------------------------
    // __before / __after
    // -----------------------------------------------------------------------

    function __before() internal {
        _before = _snapshotVars();
    }

    function __after() internal {
        _after = _snapshotVars();

        // Update canary booleans based on currentOperation
        bytes4 op = currentOperation;
        if (op == SelectorStorage.CASH_MANAGER_REQUEST_MINT)
            ghost_requestMintReached = true;
        if (op == SelectorStorage.CASH_MANAGER_CLAIM_MINT)
            ghost_claimMintReached = true;
        if (op == SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION)
            ghost_requestRedemptionReached = true;
        if (op == SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS)
            ghost_completeRedemptionsReached = true;
        if (op == SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE)
            ghost_setRateReached = true;
        if (op == SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE)
            ghost_overrideRateReached = true;
        if (op == SelectorStorage.CASH_MANAGER_TRANSITION_EPOCH)
            ghost_transitionEpochReached = true;

        // Update high-water mark
        if (_after.currentEpoch > ghost_lastEpoch) {
            ghost_lastEpoch = _after.currentEpoch;
        }
    }
}
