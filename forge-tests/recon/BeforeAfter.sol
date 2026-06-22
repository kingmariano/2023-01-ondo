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
    // Ghost accumulators (Phase 3B)
    // -----------------------------------------------------------------------

    /// @notice Cumulative collateral deposited (after fees) into requestMint
    ///         across all calls.  Incremented in __after() when requestMint fires.
    uint256 public ghost_totalCollateralDeposited;

    /// @notice Cumulative CASH minted to users via claimMint.
    ///         Used for PROFIT conservation checks.
    uint256 public ghost_totalCashMinted;

    /// @notice Cumulative CASH burned in requestRedemption.
    uint256 public ghost_totalCashBurned;

    /// @notice Cumulative CASH refunded via completeRedemptions (refundees).
    ///         Tracked indirectly via totalSupply increase after completeRedemptions.
    uint256 public ghost_totalCashRefunded;

    /// @notice Per-epoch ghost: has a rate been set for this epoch?
    ///         Used for T12-01 immutability check — we track whether we observed
    ///         a non-zero rate for an epoch before (epochToExchangeRate set once).
    ///         Key = epoch, Value = first rate observed (0 if never set).
    mapping(uint256 => uint256) public ghost_epochFirstRate;

    /// @notice Per-(epoch, actor) mint request sum — ghost accumulator for T14-04.
    ///         Incremented by depositValueAfterFees (tracked indirectly via
    ///         mintRequestsPerEpoch delta in __after).
    mapping(uint256 => mapping(address => uint256)) public ghost_mintRequestSum;

    /// @notice Tracks whether overrideExchangeRate was ever called with rate < MIN_SAFE_RATE.
    ///         Used for ECO-02 alert.
    bool public ghost_lowRateOverrideDetected;
    uint256 public ghost_lowRateOverrideValue;

    /// @notice Tracks the assetSender address snapshotted before calls — for FF-06 doom check.
    address public ghost_lastAssetSender;

    /// @notice Tracks whether setEpochDuration(0) was called — for FF-07 doom check.
    bool public ghost_epochDurationZeroSet;

    /// @notice Tracks whether overrideExchangeRate was called with rate == 0
    ///         for the current epoch — for doom claimMint path.
    bool public ghost_overrideRateZeroForCurrentEpoch;
    uint256 public ghost_overrideZeroEpoch;

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

        // Phase 3B additions
        // exchangeRateDeltaLimit at snapshot time
        uint256 exchangeRateDeltaLimit;
        // assetSender at snapshot time
        address assetSender;
        // epochDuration at snapshot time (for DOOM-FF-07)
        uint256 epochDurationSnapshot;
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

        // Phase 3B snapshot fields
        v.exchangeRateDeltaLimit  = cashManager.exchangeRateDeltaLimit();
        v.assetSender             = cashManager.assetSender();
        v.epochDurationSnapshot   = cashManager.epochDuration();
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

        // ----------------------------------------------------------------
        // Phase 3B ghost accumulator updates
        // ----------------------------------------------------------------

        // PROFIT-05 / SOL-01 — track cumulative minted/burned/refunded CASH
        if (op == SelectorStorage.CASH_MANAGER_CLAIM_MINT) {
            // claimMint mints CASH to user: totalSupply increases
            if (_after.totalSupply > _before.totalSupply) {
                ghost_totalCashMinted += _after.totalSupply - _before.totalSupply;
            }
        }
        if (op == SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION) {
            // requestRedemption burns CASH: totalSupply decreases
            if (_before.totalSupply > _after.totalSupply) {
                ghost_totalCashBurned += _before.totalSupply - _after.totalSupply;
            }
        }
        if (op == SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) {
            // completeRedemptions may mint (refunds) — track supply increase
            if (_after.totalSupply > _before.totalSupply) {
                ghost_totalCashRefunded += _after.totalSupply - _before.totalSupply;
            }
        }

        // PROFIT-02 / T14-04 — requestMint collateral accumulator
        if (op == SelectorStorage.CASH_MANAGER_REQUEST_MINT) {
            // Accumulate per-(epoch, actor) mint requests from snapshot delta
            address actor = _getActor();
            uint256 ep = _after.currentEpoch;
            // After requestMint the mintRequests slot increased by depositValueAfterFees
            uint256 afterReq = cashManager.mintRequestsPerEpoch(ep, actor);
            uint256 beforeReq = (_before.currentEpoch == ep)
                ? _before.mintRequestsActorCurrentEpoch : 0;
            if (afterReq > beforeReq) {
                uint256 deposited = afterReq - beforeReq;
                ghost_totalCollateralDeposited += deposited;
                ghost_mintRequestSum[ep][actor] += deposited;
            }
        }

        // T12-01 — first-set immutability: record first observed non-zero rate per epoch
        {
            uint256 ep2 = _after.currentEpoch;
            // Check previous epoch (rate set for past epochs by setMintExchangeRate / override)
            // We record the first time we see a non-zero rate for each epoch
            if (ep2 > 0) {
                uint256 prevEp = ep2 - 1;
                uint256 prevRate = cashManager.epochToExchangeRate(prevEp);
                if (prevRate != 0 && ghost_epochFirstRate[prevEp] == 0) {
                    ghost_epochFirstRate[prevEp] = prevRate;
                }
            }
            // Also check current epoch (in case override sets current-ish epoch)
            uint256 curRate = _after.epochToExchangeRateCurrent;
            if (curRate != 0 && ghost_epochFirstRate[ep2] == 0) {
                ghost_epochFirstRate[ep2] = curRate;
            }
        }

        // ECO-02 — overrideExchangeRate with very low rate alert
        if (op == SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE) {
            uint256 newRate = _after.lastSetMintExchangeRate;
            uint256 minSafeRate = 1e3; // mirror of Properties.MIN_SAFE_RATE
            if (newRate > 0 && newRate < minSafeRate) {
                ghost_lowRateOverrideDetected = true;
                ghost_lowRateOverrideValue = newRate;
            }
            // Also check the epochToExchangeRate for any epoch that now has a zero rate
            // (overrideExchangeRate(0, epoch, ...) bricks claimMint for that epoch)
            // We check the before-after rate for last known epoch
        }

        // DOOM — track assetSender == address(0) after setAssetSender
        if (op == SelectorStorage.CASH_MANAGER_SET_ASSET_SENDER) {
            ghost_lastAssetSender = _after.assetSender;
        }

        // DOOM — track epochDuration == 0 after setEpochDuration
        if (op == SelectorStorage.CASH_MANAGER_SET_EPOCH_DURATION) {
            if (_after.epochDurationSnapshot == 0) {
                ghost_epochDurationZeroSet = true;
            }
        }
    }
}
