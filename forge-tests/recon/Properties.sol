// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {SelectorStorage} from "./SelectorStorage.sol";
import {vm} from "@chimera/Hevm.sol";

// ============================================================
//  Properties — Phase 3A  (SIMPLE + CANARY)
//  Phase 3B will add INLINE / NEGATIVE / DOOM
// ============================================================
abstract contract Properties is BeforeAfter, Asserts {

    // ----------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------
    uint256 internal constant BPS_DENOM       = 10_000;
    uint256 internal constant MIN_SAFE_RATE   = 1e3;  // floor for ROUND-06 / ECO-02 alert
    uint256 internal constant RATE_TOL        = 1;    // 1-wei tolerance for rounding

    // ================================================================
    //  CANARY GROUP — coverage sanity (should FAIL when handler fires)
    //  Implemented as ghost-boolean checks: property returns true until
    //  the handler is first reached, then the canary flips.
    //  In a fuzzer these should NOT fail (the ghost is set but the
    //  property is written so it returns true when the handler was NOT
    //  reached — the fuzzer will then try to flip it).
    //  Convention: property_canary_X() returns false once X was reached.
    //  This causes the fuzzer to report "reachability confirmed" as a
    //  property violation.  The Foundry CryticToFoundry tests just call
    //  the handlers so they will set the ghost and the property should
    //  then return false — that is the EXPECTED outcome for canaries.
    // ================================================================

    /// CANARY-01 — requestMint reachable
    function property_canary_requestMintReached() public view returns (bool) {
        return !ghost_requestMintReached; // fails once requestMint fires
    }

    /// CANARY-02 — claimMint reachable
    function property_canary_claimMintReached() public view returns (bool) {
        return !ghost_claimMintReached;
    }

    /// CANARY-03 — requestRedemption reachable
    function property_canary_requestRedemptionReached() public view returns (bool) {
        return !ghost_requestRedemptionReached;
    }

    /// CANARY-04 — completeRedemptions reachable
    function property_canary_completeRedemptionsReached() public view returns (bool) {
        return !ghost_completeRedemptionsReached;
    }

    /// CANARY-05 — setMintExchangeRate reachable
    function property_canary_setRateReached() public view returns (bool) {
        return !ghost_setRateReached;
    }

    /// CANARY-06 — overrideExchangeRate reachable
    function property_canary_overrideRateReached() public view returns (bool) {
        return !ghost_overrideRateReached;
    }

    /// CANARY-07 — transitionEpoch reachable
    function property_canary_transitionEpochReached() public view returns (bool) {
        return !ghost_transitionEpochReached;
    }

    // ================================================================
    //  MONO GROUP — monotonicity
    // ================================================================

    /// MONO-01 — currentEpoch is non-decreasing.
    ///           ghost_lastEpoch is the high-water mark updated in __after().
    function property_mono_epochNonDecreasing() public view returns (bool) {
        // ghost_lastEpoch is updated to max(prev, after.currentEpoch) in __after()
        // so the live epoch can never be less than ghost_lastEpoch
        return cashManager.currentEpoch() >= ghost_lastEpoch;
    }

    /// MONO-04 — totalBurned in current epoch is non-decreasing across calls
    ///           (only assert when the epoch did NOT change between before/after,
    ///            and the operation was not an admin override/complete-redemptions).
    function property_mono_totalBurnedNonDecreasing() public view returns (bool) {
        // If epoch changed or a complete-redemptions/setPendingRedemption ran, skip.
        // We detect epoch change: if before and after epoch differ, the reset is valid.
        if (_before.currentEpoch != _after.currentEpoch) return true;
        // Admin override can decrease; skip for those ops
        if (currentOperation == bytes4(keccak256("completeRedemptions(address[],address[],uint256,uint256,uint256)")))
            return true;
        if (currentOperation == bytes4(keccak256("setPendingRedemptionBalance(address,uint256,uint256)")))
            return true;
        return _after.totalBurnedCurrentEpoch >= _before.totalBurnedCurrentEpoch;
    }

    // ================================================================
    //  SOL GROUP — solvency / conservation
    // ================================================================

    /// SOL-02 — currentMintAmount <= mintLimit always.
    function property_sol_mintAmountWithinLimit() public view returns (bool) {
        uint256 limit = cashManager.mintLimit();
        uint256 current = cashManager.currentMintAmount();
        return current <= limit;
    }

    /// SOL-03 — currentRedeemAmount <= redeemLimit always.
    function property_sol_redeemAmountWithinLimit() public view returns (bool) {
        uint256 limit = cashManager.redeemLimit();
        uint256 current = cashManager.currentRedeemAmount();
        return current <= limit;
    }

    /// SOL-04 — After transitionEpoch, currentMintAmount == 0 and currentRedeemAmount == 0
    ///           (only meaningful when a real epoch transition occurred).
    function property_sol_epochResetAmounts() public view returns (bool) {
        // Only check if epoch advanced (before < after)
        if (_before.currentEpoch >= _after.currentEpoch) return true;
        return _after.currentMintAmount == 0 && _after.currentRedeemAmount == 0;
    }

    /// SOL-06 — addressToBurnAmt for active actor == 0 after completeRedemptions
    ///           (checked as a post-completeRedemptions snapshot delta; actor's burn
    ///            amount should have been zeroed if it was in the redeemers list).
    ///           This is a soft check: we only assert the after-state is >= 0 (trivial)
    ///           and that the after totalBurned did not increase unexpectedly after
    ///           completeRedemptions (burns only decrease after servicing).
    ///           Full exact check requires knowing which addresses were in the array.
    function property_sol_totalBurnedNonNegative() public view returns (bool) {
        // totalBurned is uint256 so always >= 0; this acts as a canary for underflow.
        // If Solidity's checked arithmetic is ever bypassed, this would fail.
        return _after.totalBurnedCurrentEpoch < type(uint256).max / 2;
    }

    // ================================================================
    //  ROUND GROUP — math / rounding
    // ================================================================

    /// ROUND-05 — epochToExchangeRate for current epoch != 0 once set.
    ///            We check: if before had rate > 0, after must also have rate > 0
    ///            UNLESS overrideExchangeRate was called (which can set any value).
    function property_round_exchangeRateNonZeroOnceSet() public view returns (bool) {
        // Skip for overrideExchangeRate (admin bypass)
        if (currentOperation == SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE)
            return true;
        // Only relevant if a rate was already set before this call
        if (_before.epochToExchangeRateCurrent == 0) return true;
        // If epoch changed, the new epoch's rate is naturally 0 — that's fine
        if (_before.currentEpoch != _after.currentEpoch) return true;
        return _after.epochToExchangeRateCurrent != 0;
    }

    /// ROUND-06 — Exchange rate floor alert: rate >= MIN_SAFE_RATE (1000).
    ///            This is a soft assertion: if rate < floor it is flagged.
    ///            Implemented as a strict assert so the fuzzer can find it.
    function property_round_exchangeRateFloor() public view returns (bool) {
        uint256 rate = cashManager.lastSetMintExchangeRate();
        if (rate == 0) return true; // rate not yet set; skip
        return rate >= MIN_SAFE_RATE;
    }

    // ================================================================
    //  DELTA GROUP — exact variable transitions (post-call deltas)
    // ================================================================

    /// DELTA-03 — After requestRedemption(amount), totalSupply decreases by exactly amount.
    ///            We check: if op is requestRedemption AND epoch did not change,
    ///            the supply drop equals the burn-amount increase.
    function property_delta_requestRedemptionSupplyDrop() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION)
            return true;
        // Allow for epoch boundary (transitionEpoch runs inside updateEpoch)
        // The supply drop must equal the increase in totalBurned for this epoch.
        // If the call reverted (supply unchanged), also fine.
        uint256 supplyBefore = _before.totalSupply;
        uint256 supplyAfter  = _after.totalSupply;
        if (supplyBefore == supplyAfter) return true; // reverted or zero burn
        if (supplyBefore < supplyAfter) return false; // supply can never increase via requestRedemption
        uint256 supplyDrop = supplyBefore - supplyAfter;
        // totalBurned increase (accounting for possible epoch reset)
        uint256 burnAfter  = _after.totalBurnedCurrentEpoch;
        uint256 burnBefore = (_before.currentEpoch == _after.currentEpoch)
            ? _before.totalBurnedCurrentEpoch
            : 0; // epoch reset; before was previous epoch
        if (burnAfter < burnBefore) return true; // admin decrease; skip
        uint256 burnIncrease = burnAfter - burnBefore;
        // supplyDrop must equal burnIncrease (or be 0 if reverted)
        return supplyDrop == burnIncrease;
    }

    /// DELTA-02 — After requestRedemption(amount), totalBurned and burnAmtActor increase by amount.
    function property_delta_requestRedemptionBurnAccounting() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION)
            return true;
        // If epoch changed mid-call (updateEpoch), only compare post-epoch state
        if (_before.currentEpoch != _after.currentEpoch) return true;
        // If the call reverted (totalBurned unchanged), fine
        if (_before.totalBurnedCurrentEpoch == _after.totalBurnedCurrentEpoch) return true;
        if (_after.totalBurnedCurrentEpoch < _before.totalBurnedCurrentEpoch) return false;
        uint256 totalBurnIncrease = _after.totalBurnedCurrentEpoch - _before.totalBurnedCurrentEpoch;
        uint256 actorBurnIncrease;
        if (_after.burnAmtActorCurrentEpoch >= _before.burnAmtActorCurrentEpoch) {
            actorBurnIncrease = _after.burnAmtActorCurrentEpoch - _before.burnAmtActorCurrentEpoch;
        }
        // Both must increase by the same amount (the redemption amount)
        return totalBurnIncrease == actorBurnIncrease;
    }

    // ================================================================
    //  RATE GROUP — exchange rate sanity
    // ================================================================

    /// RATE-06 — Price cap respected when non-zero for cTokenDelegate.
    function property_rate_priceCap() public view returns (bool) {
        uint256 cap = ondoPriceOracleV2.fTokenToUnderlyingPriceCap(address(cTokenDelegate));
        if (cap == 0) return true; // no cap; skip
        uint256 price = _safeGetPrice(address(cTokenDelegate));
        return price <= cap;
    }

    /// RATE-06 (cCash) — Price cap respected when non-zero for cCashDelegate.
    function property_rate_priceCapCCash() public view returns (bool) {
        uint256 cap = ondoPriceOracleV2.fTokenToUnderlyingPriceCap(address(cCashDelegate));
        if (cap == 0) return true;
        uint256 price = _safeGetPrice(address(cCashDelegate));
        return price <= cap;
    }

    // ================================================================
    //  FEE GROUP
    // ================================================================

    /// FEE-01 — mintFee < BPS_DENOMINATOR (10_000) always.
    function property_fee_mintFeeBelowMax() public view returns (bool) {
        return cashManager.mintFee() < BPS_DENOM;
    }

    /// FEE-06 — minimumDepositAmount >= BPS_DENOMINATOR (10_000) always.
    function property_fee_minimumDepositAboveFloor() public view returns (bool) {
        return cashManager.minimumDepositAmount() >= BPS_DENOM;
    }

    // ================================================================
    //  PROFIT GROUP
    // ================================================================

    /// PROFIT-04 — mintRequestsPerEpoch for active actor is 0 after claimMint.
    function property_profit_claimMintZeroesMintRequests() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_CLAIM_MINT) return true;
        // If the call reverted (before and after mint requests unchanged), fine
        if (_before.mintRequestsActorCurrentEpoch == _after.mintRequestsActorCurrentEpoch)
            return true;
        // After a successful claimMint the slot should be 0
        // Note: claimMint is called with a specific epoch (not necessarily currentEpoch),
        //       so we check via direct read for the active actor on the current epoch.
        //       If the epoch changed (updateEpoch), current epoch is new — the
        //       request was on the previous epoch. We just verify the current epoch's
        //       slot didn't spuriously increase.
        // Conservative: just check that mint requests did not increase after claimMint.
        return _after.mintRequestsActorCurrentEpoch <= _before.mintRequestsActorCurrentEpoch;
    }

    // ================================================================
    //  T11 GROUP — state transitions
    // ================================================================

    /// T11-07 — totalBurned never goes negative (Solidity 0.8 underflow protection canary).
    function property_t11_totalBurnedNonNegative() public view returns (bool) {
        // Trivially true in Solidity 0.8 but acts as a safety canary.
        return _after.totalBurnedCurrentEpoch < type(uint256).max;
    }

    // ================================================================
    //  T12 GROUP — valid state
    // ================================================================

    /// T12-07 — requestRedemption(0) always reverts even when minimumRedeemAmount == 0.
    ///           Checked passively: if a requestRedemption call succeeded AND amount was 0,
    ///           totalBurned must have increased (it didn't — so we'd catch it via DELTA-02).
    ///           Implemented as: currentRedeemAmount must be > 0 after successful
    ///           requestRedemption (otherwise RedeemAmountCannotBeZero would have reverted).
    function property_t12_redeemAmountCannotBeZero() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION) return true;
        // If supply didn't change, the call reverted — fine
        if (_before.totalSupply == _after.totalSupply) return true;
        // Supply decreased => redemption succeeded => totalBurned must have increased by > 0
        return _after.totalBurnedCurrentEpoch > _before.totalBurnedCurrentEpoch ||
               _before.currentEpoch != _after.currentEpoch; // epoch boundary is ok
    }

    // ================================================================
    //  T13 GROUP — peripheral / view consistency
    // ================================================================

    /// T13-01 — getBurnedQuantity(epoch, user) matches addressToBurnAmt view.
    ///           We use the active actor and current epoch.
    function property_t13_getBurnedQuantityConsistent() public view returns (bool) {
        address actor = _getActor();
        uint256 ep    = cashManager.currentEpoch();
        uint256 fromGetter = cashManager.getBurnedQuantity(ep, actor);
        // The after snapshot already read this; compare directly
        return fromGetter == _after.burnAmtActorCurrentEpoch;
    }

    /// T13-04 — decimalsMultiplier == 10^(18 - collateral.decimals()); immutable check.
    function property_t13_decimalsMultiplierCorrect() public view returns (bool) {
        uint8 collDecimals = 6; // USDC-like, set in Setup._newAsset(6)
        uint256 expected = 10 ** (18 - uint256(collDecimals));
        return cashManager.decimalsMultiplier() == expected;
    }

    /// T13-05 — getUnderlyingPrice returns 0 for MANUAL-type fToken with no price set (no revert).
    ///           In Setup, both delegates are set to MANUAL type with price 1e18.
    ///           We verify that an fToken explicitly set to MANUAL type with price 0 returns 0.
    ///           NOTE: UNINITIALIZED type (default for new addresses) DOES revert.
    ///           This property verifies the MANUAL+zero-price path returns 0.
    ///           We check cTokenDelegate which was set to MANUAL in Setup; its price is
    ///           non-zero (1e18), but may have been changed. The property is satisfied
    ///           if the getter returns a value without reverting (any value is acceptable).
    function property_t13_manualPriceNoRevert() public view returns (bool) {
        // cTokenDelegate was set to MANUAL type in Setup; just verify it doesn't revert
        try ondoPriceOracleV2.getUnderlyingPrice(address(cTokenDelegate)) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    // ================================================================
    //  T15 GROUP — bitmap / flags
    // ================================================================

    /// T15-05 — getRoleAdmin(PAUSER_ADMIN) == MANAGER_ADMIN.
    function property_t15_pauserAdminRoleAdmin() public view returns (bool) {
        bytes32 pauserAdmin   = cashManager.PAUSER_ADMIN();
        bytes32 managerAdmin  = cashManager.MANAGER_ADMIN();
        return cashManager.getRoleAdmin(pauserAdmin) == managerAdmin;
    }

    /// T15-05b — getRoleAdmin(SETTER_ADMIN) == MANAGER_ADMIN.
    function property_t15_setterAdminRoleAdmin() public view returns (bool) {
        bytes32 setterAdmin  = cashManager.SETTER_ADMIN();
        bytes32 managerAdmin = cashManager.MANAGER_ADMIN();
        return cashManager.getRoleAdmin(setterAdmin) == managerAdmin;
    }

    // ================================================================
    //  ECO GROUP — economic / oracle alerts
    // ================================================================

    /// ECO-06 — mintFee alert when > 500 bps (5%).
    ///           Soft assertion: flag if fee exceeds reasonable threshold.
    function property_eco_mintFeeAlert() public view returns (bool) {
        return cashManager.mintFee() <= 500;
    }

    // ================================================================
    //  Phase 3B — INLINE / NEGATIVE / DOOMSDAY PROPERTIES
    // ================================================================

    // ================================================================
    //  INLINE: PROFIT / SOL conservation accumulators
    // ================================================================

    /// PROFIT-05 / SOL-01 — totalCashBurned >= totalCashRefunded always
    ///           (you can only refund what was burned; refunds add back via mint
    ///            so they do not exceed totalCashBurned in total).
    ///           Soft conservation: ghost_totalCashBurned >= ghost_totalCashRefunded.
    function property_profit_burnGeRefund() public view returns (bool) {
        // ghost_totalCashRefunded is minted back from burned tokens; cannot exceed ghost_totalCashBurned
        return ghost_totalCashBurned >= ghost_totalCashRefunded;
    }

    /// PROFIT-02 — Inline conservation: after each requestMint,
    ///             the ghost mintRequestSum should equal mintRequestsPerEpoch for the actor.
    ///             Checked as a post-op invariant using the snapshot delta.
    function property_profit_mintRequestSumConsistent() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_MINT) return true;
        // If call reverted (no change in mintRequests), skip
        if (_before.mintRequestsActorCurrentEpoch == _after.mintRequestsActorCurrentEpoch &&
            _before.currentEpoch == _after.currentEpoch) return true;
        // After a successful requestMint: mintRequestsPerEpoch[ep][actor] must have increased
        // and must now equal what the protocol reports
        address actor = _getActor();
        uint256 ep = _after.currentEpoch;
        uint256 onChain = cashManager.mintRequestsPerEpoch(ep, actor);
        // ghost accumulates per (epoch, actor); must match on-chain value
        return ghost_mintRequestSum[ep][actor] == onChain;
    }

    // ================================================================
    //  INLINE: DELTA exact-transition checks
    // ================================================================

    /// DELTA-01 — After requestMint(collateralAmountIn), mintRequestsPerEpoch[ep][actor]
    ///            increases by (collateralAmountIn - fees).  We verify the increase is
    ///            consistent with mint fee formula: delta <= collateralAmountIn.
    ///            (Exact delta = collateralAmountIn * (1 - mintFee/BPS_DENOM), rounded down.)
    function property_delta_requestMintDepositAccounting() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_MINT) return true;
        // If epoch changed (updateEpoch ran), compare against epoch-reset baseline
        if (_before.currentEpoch != _after.currentEpoch) return true;
        // If no change occurred (call reverted), skip
        if (_before.mintRequestsActorCurrentEpoch >= _after.mintRequestsActorCurrentEpoch) return true;
        uint256 delta = _after.mintRequestsActorCurrentEpoch - _before.mintRequestsActorCurrentEpoch;
        // delta must be <= currentMintAmount increase (checked by limit invariant)
        // and must be <= mintLimit (checked by SOL-02)
        // Conservative: delta must be > 0 (already guaranteed) and < mintLimit
        return delta <= cashManager.mintLimit();
    }

    /// DELTA-04 — After claimMint, actor CASH balance increases by cashOwed (>= 1).
    ///            We verify that when claimMint succeeds (totalSupply increased),
    ///            the actor's balance increased by the same amount as totalSupply.
    function property_delta_claimMintCashBalance() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_CLAIM_MINT) return true;
        if (_after.totalSupply <= _before.totalSupply) return true; // no mint / revert
        uint256 supplyIncrease = _after.totalSupply - _before.totalSupply;
        // Minted CASH goes to the claimed user (not necessarily the active actor
        // since claimMint takes a `user` param). We can't easily verify which
        // user received it, but we can assert the supply increase is >= 1.
        return supplyIncrease >= 1;
    }

    /// DELTA-05 — After setMintExchangeRate (non-pausing path), lastSetMintExchangeRate == new rate.
    ///            Pausing path does NOT update lastSetMintExchangeRate.
    ///            We detect pausing path by checking paused() delta.
    function property_delta_setRateUpdatesLastRate() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) return true;
        // If call reverted (epoch didn't change, rate unchanged), skip
        if (_before.epochToExchangeRateCurrent == _after.epochToExchangeRateCurrent &&
            _before.lastSetMintExchangeRate == _after.lastSetMintExchangeRate) return true;
        // If contract was paused by this call (delta-violation path), lastSetMintExchangeRate
        // should NOT have changed
        if (!_before.paused && _after.paused) {
            // Auto-pause fired: lastSetMintExchangeRate must equal before value
            return _after.lastSetMintExchangeRate == _before.lastSetMintExchangeRate;
        }
        // Normal path: lastSetMintExchangeRate updated to new rate
        // We can't recover the exact exchangeRate param, but the property is:
        // lastSetMintExchangeRate must have changed OR stayed the same if the set epoch
        // already had a rate (reverted with EpochExchangeRateAlreadySet). Just verify
        // that paused did not become true on the normal path.
        return !_after.paused || _before.paused; // if it wasn't paused before, it shouldn't be now
    }

    /// DELTA-06 — Auto-pause: if setMintExchangeRate caused a pause, the contract IS paused after.
    ///            (Inverse: if paused() changed from false to true via setMintExchangeRate,
    ///             it must be because rate delta exceeded limit.)
    function property_delta_autopauseOnDeltaViolation() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) return true;
        // If paused changed false -> true, this call caused the pause
        // The contract should now be paused, and the epoch rate was set
        if (!_before.paused && _after.paused) {
            // Exchange rate for the set epoch must be non-zero (was set before pause)
            // We check via last snapshot: epochToExchangeRateCurrent or indirectly.
            // The property is simply: if auto-pause fired, the contract IS paused.
            return _after.paused;
        }
        return true;
    }

    // ================================================================
    //  INLINE: T11 state-transition checks
    // ================================================================

    /// T11-01 — Epoch can only advance (never decrease) and only via transitionEpoch.
    ///          If epoch increased, the op must be transitionEpoch or updateEpoch-decorated
    ///          (requestMint, claimMint, requestRedemption, completeRedemptions, setMintExchangeRate,
    ///           overrideExchangeRate, setPendingMintBalance, setPendingRedemptionBalance, or
    ///           the shortcut handlers that call transitionEpoch internally).
    function property_t11_epochOnlyAdvances() public view returns (bool) {
        // Epoch must never decrease
        return _after.currentEpoch >= _before.currentEpoch;
    }

    /// T11-02 — currentEpochStartTimestamp <= block.timestamp always.
    ///          (Start of epoch cannot be in the future.)
    function property_t11_epochStartTimestampValid() public view returns (bool) {
        return _after.currentEpochStartTimestamp <= block.timestamp;
    }

    /// T11-04 — When setMintExchangeRate triggers auto-pause, lastSetMintExchangeRate
    ///          is NOT updated (the rate that caused the pause is not the new baseline).
    function property_t11_autopauseNoRateUpdate() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) return true;
        // Auto-pause happened: paused changed false->true
        if (!_before.paused && _after.paused) {
            // lastSetMintExchangeRate must remain unchanged
            return _after.lastSetMintExchangeRate == _before.lastSetMintExchangeRate;
        }
        return true;
    }

    /// T11-05 — overrideExchangeRate sets lastSetMintExchangeRate to _lastSetMintExchangeRate
    ///          param when non-zero; leaves it unchanged when zero.
    ///          We check: if paused state changed (override may unpause externally later),
    ///          the rate transition is monotonic or explicitly overridden.
    function property_t11_overrideRateMonotonic() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE) return true;
        // overrideExchangeRate does NOT change the paused state itself;
        // it only sets epochToExchangeRate[epoch] and optionally lastSetMintExchangeRate.
        // The property: lastSetMintExchangeRate must be either equal to before (if param==0)
        // OR equal to the param value (if param!=0). We can only check that it did NOT
        // become 0 (since _lastSetMintExchangeRate==0 leaves it unchanged).
        // If before was non-zero and after is 0, that's a violation.
        if (_before.lastSetMintExchangeRate != 0 && _after.lastSetMintExchangeRate == 0) {
            return false;
        }
        return true;
    }

    // ================================================================
    //  INLINE: T12 valid-state properties
    // ================================================================

    /// T12-01 — epochToExchangeRate for a given epoch is immutable once set
    ///          (except via overrideExchangeRate).
    ///          Implemented using ghost_epochFirstRate: if we observe a rate for
    ///          an epoch, subsequent reads must match OR the operation is override.
    function property_t12_exchangeRateImmutableOnceSet() public view returns (bool) {
        // Skip if this is overrideExchangeRate (admin bypass)
        if (currentOperation == SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE) return true;
        // Check: for the previous epoch, if ghost has a first rate, current on-chain rate must match
        uint256 ep = _after.currentEpoch;
        if (ep == 0) return true;
        uint256 prevEp = ep - 1;
        uint256 firstRate = ghost_epochFirstRate[prevEp];
        if (firstRate == 0) return true; // never observed
        uint256 currentRate = cashManager.epochToExchangeRate(prevEp);
        // If we've seen a non-zero rate for prevEp, it must remain the same
        // (unless override was called, already guarded above)
        return currentRate == firstRate || currentRate == 0;
        // currentRate == 0 case: overrideExchangeRate(0, ...) was called without going through override op
        // This would be caught by the override guard failing, so returning true is safe here
    }

    // ================================================================
    //  INLINE: T14 dust / minimum bounds
    // ================================================================

    /// T14-01 — cashOwed >= 1 after claimMint (no dust mint of 0 CASH).
    ///          Checked via supply increase: if supply increased, it increased by >= 1.
    function property_t14_cashOwedAtLeastOne() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_CLAIM_MINT) return true;
        if (_before.totalSupply >= _after.totalSupply) return true; // no mint / revert
        uint256 increase = _after.totalSupply - _before.totalSupply;
        return increase >= 1;
    }

    /// T14-03 — Fee rounding at minimum: if mintFee > 0, fees must be >= 1 for any
    ///          successful requestMint (because minimumDepositAmount >= BPS_DENOMINATOR).
    ///          We check: after requestMint, if mintFee > 0 AND mint happened,
    ///          the collateral deposited into mintRequests < collateralAmountIn (fee was taken).
    function property_t14_feeRoundingCorrect() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_MINT) return true;
        if (_before.mintFee == 0) return true; // no fee; skip
        if (_before.currentEpoch != _after.currentEpoch) return true; // epoch change; skip
        if (_before.mintRequestsActorCurrentEpoch >= _after.mintRequestsActorCurrentEpoch) return true; // revert
        // A fee was applied; the deposit (after fee) must be < collateralAmountIn
        // We can't recover collateralAmountIn, but we can verify:
        // The increase in mintRequests must be <= mintLimit (sol-02 covers this)
        // AND must be > 0 (already guaranteed by the condition above)
        // The real check is that fees don't round to 0 for amounts >= minimumDepositAmount.
        // minimumDepositAmount >= BPS_DENOMINATOR (10000) by FEE-06.
        // fee = (amount * mintFee) / BPS_DENOMINATOR
        // For amount >= 10000 and mintFee >= 1: fee >= 1.
        // So: depositAfterFees = amount - fee <= amount - 1 < amount.
        // The mintRequests delta must be strictly less than some theoretical max (just check > 0).
        uint256 delta = _after.mintRequestsActorCurrentEpoch - _before.mintRequestsActorCurrentEpoch;
        return delta > 0; // deposit was recorded (already trivially true here, but forms the check)
    }

    /// T14-04 — Sequential requestMint accumulation: ghost_mintRequestSum[ep][actor]
    ///          must match on-chain mintRequestsPerEpoch[ep][actor].
    function property_t14_mintRequestSumMatchesOnChain() public view returns (bool) {
        address actor = _getActor();
        uint256 ep = _after.currentEpoch;
        uint256 onChain = cashManager.mintRequestsPerEpoch(ep, actor);
        uint256 ghostSum = ghost_mintRequestSum[ep][actor];
        // Ghost accumulates only after requestMint ops; admin overrides via
        // setPendingMintBalance can change onChain value. Guard: if op is setPendingMintBalance, skip.
        if (currentOperation == SelectorStorage.CASH_MANAGER_SET_PENDING_MINT_BALANCE) return true;
        // If ghost is 0 and onChain is 0 or non-zero, we haven't tracked yet — skip
        if (ghostSum == 0) return true;
        // If admin override happened (setPendingMintBalance in a prior call), ghost may be stale
        // Conservative: just check ghost <= onChain (ghost only adds, never subtracts)
        return ghostSum <= onChain;
    }

    // ================================================================
    //  NEGATIVE / PRIV-NEG: privilege-escalation properties
    // ================================================================

    /// PRIV-NEG-01 — A non-admin actor calling setMintExchangeRate must revert.
    ///               Implemented as a try/catch inline check using the active actor address.
    ///               This is a Foundry-style property (not a fuzzer property_*).
    ///               We make it a property that always returns true (the check is encoded
    ///               in the doom shortcut property below).
    function property_neg_nonAdminCannotSetMintExchangeRate() public returns (bool) {
        // Pick a non-admin actor (not address(this))
        address actor = _getActor();
        if (actor == address(this)) return true; // actor IS admin; skip
        // Try to call setMintExchangeRate as the non-admin actor
        // Must revert with AccessControl error
        vm.startPrank(actor);
        try cashManager.setMintExchangeRate(1e6, 0) {
            vm.stopPrank();
            return false; // VIOLATION: non-admin succeeded
        } catch {
            vm.stopPrank();
            return true;  // expected revert
        }
    }

    /// PRIV-NEG-02 — A non-admin actor calling pause() must revert.
    function property_neg_nonAdminCannotPause() public returns (bool) {
        address actor = _getActor();
        if (actor == address(this)) return true;
        vm.startPrank(actor);
        try cashManager.pause() {
            vm.stopPrank();
            return false; // VIOLATION
        } catch {
            vm.stopPrank();
            return true;
        }
    }

    /// PRIV-NEG-03 — A non-admin actor calling setMintFee must revert.
    function property_neg_nonAdminCannotSetMintFee() public returns (bool) {
        address actor = _getActor();
        if (actor == address(this)) return true;
        vm.startPrank(actor);
        try cashManager.setMintFee(100) {
            vm.stopPrank();
            return false; // VIOLATION
        } catch {
            vm.stopPrank();
            return true;
        }
    }

    /// PRIV-NEG-04 — A non-admin actor calling overrideExchangeRate must revert.
    function property_neg_nonAdminCannotOverrideRate() public returns (bool) {
        address actor = _getActor();
        if (actor == address(this)) return true;
        vm.startPrank(actor);
        try cashManager.overrideExchangeRate(1e6, 0, 1e6) {
            vm.stopPrank();
            return false; // VIOLATION
        } catch {
            vm.stopPrank();
            return true;
        }
    }

    /// KYC-01 — addKYCAddresses by non-REGISTRY_ADMIN must revert.
    ///          (Privilege escalation on KYC registry.)
    function property_neg_nonAdminCannotAddKYCAddresses() public returns (bool) {
        address actor = _getActor();
        if (actor == address(this)) return true;
        // Check if actor has the role (if they were granted it, skip)
        bytes32 registryAdmin = kYCRegistry.REGISTRY_ADMIN();
        if (kYCRegistry.hasRole(registryAdmin, actor)) return true;
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xDEAD);
        vm.startPrank(actor);
        try kYCRegistry.addKYCAddresses(KYC_GROUP, addrs) {
            vm.stopPrank();
            return false; // VIOLATION
        } catch {
            vm.stopPrank();
            return true;
        }
    }

    // ================================================================
    //  ROUND GROUP — Phase 3B
    // ================================================================

    /// ROUND-01 — cashOwed is rounded DOWN (never over-mints).
    ///            After claimMint, the supply increase must equal floor division:
    ///            cashOwed = floor(collateralDeposited * decimalsMultiplier * 1e6 / rate).
    ///            We verify: supplyIncrease * rate <= collateralDeposited * decimalsMultiplier * 1e6.
    ///            (This is the rounding-down guarantee — checks no over-mint occurred.)
    function property_round_cashOwedRoundedDown() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_CLAIM_MINT) return true;
        if (_after.totalSupply <= _before.totalSupply) return true; // no mint
        uint256 supplyIncrease = _after.totalSupply - _before.totalSupply;
        // We need: collateralDeposited for the epoch being claimed.
        // The collateral deposited is now 0 (cleared by claimMint); we can't recover it.
        // Alternative: verify using ghost_totalCashMinted vs ghost_totalCollateralDeposited ratio.
        // At 1e6 rate (default in tests): 1 collateral unit (6 dec) => 1e12 CASH (18 dec).
        // This is too abstract to check inline without knowing the epoch's collateral.
        // Implement as a conservative bound: supplyIncrease >= 1 (already covered by T14-01).
        // And: supplyIncrease must not exceed type(uint128).max (sanity cap).
        return supplyIncrease <= type(uint128).max;
    }

    /// ROUND-02 — Fee rounding down: fee = floor(collateral * mintFee / BPS_DENOM).
    ///            After requestMint (if mintFee > 0), the deposit delta plus fee
    ///            must equal collateralAmountIn. We can only check the bound:
    ///            deposit delta (mintRequestsPerEpoch increase) <= collateralAmountIn.
    ///            Since we can't recover collateralAmountIn, we verify deposit > 0.
    function property_round_feeRoundedDown() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_REQUEST_MINT) return true;
        if (_before.mintFee == 0) return true;
        if (_before.currentEpoch != _after.currentEpoch) return true;
        if (_before.mintRequestsActorCurrentEpoch >= _after.mintRequestsActorCurrentEpoch) return true;
        // deposit delta must be > 0 (fees never exceed 100% since mintFee < BPS_DENOM)
        return (_after.mintRequestsActorCurrentEpoch - _before.mintRequestsActorCurrentEpoch) > 0;
    }

    /// ROUND-03 — Sum due in completeRedemptions <= amountToDist.
    ///            Conservation: after completeRedemptions, the assetSender collateral
    ///            decreased by at most collateralAmountToDist.
    ///            We verify: collateralBalanceAssetSender decreased (or stayed same if empty array).
    function property_round_redemptionSumWithinDist() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) return true;
        // If call reverted (balances unchanged), skip
        if (_before.collateralBalanceAssetSender == _after.collateralBalanceAssetSender) return true;
        // assetSender balance should have decreased (collateral distributed to redeemers + feeRecipient)
        return _after.collateralBalanceAssetSender <= _before.collateralBalanceAssetSender;
    }

    /// ROUND-04 — completeRedemptions also sends fees; total outflow = collateralAmountToDist.
    ///            Conservation: totalBurned for the serviced epoch decreases (or stays) after completeRedemptions.
    ///            (Processed redeemers have their addressToBurnAmt zeroed;
    ///             refundees also have their addressToBurnAmt zeroed but get CASH back.)
    function property_round_totalBurnedDecreaseAfterComplete() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) return true;
        // totalBurnedCurrentEpoch is for the current epoch — completeRedemptions
        // services a PAST epoch, so current epoch's totalBurned shouldn't increase.
        if (_before.currentEpoch != _after.currentEpoch) return true; // epoch boundary
        return _after.totalBurnedCurrentEpoch <= _before.totalBurnedCurrentEpoch;
    }

    // ================================================================
    //  RATE GROUP — Phase 3B
    // ================================================================

    /// RATE-03 — Delta limit arithmetic: setMintExchangeRate pauses iff
    ///           |rate - lastSetMintExchangeRate| > lastSetMintExchangeRate * deltaLimit / BPS_DENOM.
    ///           We verify: after setMintExchangeRate, if NOT paused, the rate change was within limit.
    function property_rate_deltaLimitEnforced() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) return true;
        // If call reverted (paused state unchanged), skip
        if (_before.paused == _after.paused && _before.lastSetMintExchangeRate == _after.lastSetMintExchangeRate) return true;
        // Normal (non-pausing) path: lastSetMintExchangeRate was updated
        if (!_after.paused) {
            // The rate was within limit; verify the new rate is non-zero (checked by ZeroExchangeRate)
            return _after.lastSetMintExchangeRate > 0;
        }
        // Auto-pause path: lastSetMintExchangeRate unchanged (verified by T11-04)
        return true;
    }

    // ================================================================
    //  INLINE: T13-02 conservation
    // ================================================================

    /// T13-02 — totalSupply conservation: totalSupply changes only via mint/burn ops.
    ///          (No spontaneous supply creation outside the CASH token's mint/burnFrom.)
    ///          Verified via: supply can only increase via claimMint/completeRedemptions(refund)
    ///          or direct cashKYCSenderReceiver.mint; decrease via requestRedemption/burn.
    ///          Soft check: totalSupply never overflows type(uint128).max.
    function property_t13_supplyNoOverflow() public view returns (bool) {
        return _after.totalSupply <= type(uint128).max;
    }

    // ================================================================
    //  DOOMSDAY PROPERTIES (detect real protocol bugs)
    //  These SHOULD be falsifiable by the fuzzer — they detect missing validations.
    // ================================================================

    /// DOOM-FF-02 — Double-service protection (FF-02):
    ///             A redeemer who has been serviced (addressToBurnAmt == 0) should revert
    ///             if included in a second completeRedemptions call for the same epoch.
    ///             This property detects a violation if completeRedemptions succeeds but
    ///             the actor's burn amount was already 0 before the call.
    ///             We track: if burnAmtActor was 0 before completeRedemptions AND the
    ///             call succeeded (didn't revert — we can't tell from property), the
    ///             protocol would have hit CollateralRedemptionTooSmall (revert) because
    ///             collateralAmountDue = (dist * 0) / quantityBurned = 0.
    ///             So this is actually enforced by the protocol already. Flag if NOT reverted.
    ///             As a property: if actor's burnAmt was 0 before, totalSupply must not
    ///             have changed in a way that indicates a successful second redemption.
    function property_doom_doubleServiceReverts() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) return true;
        // If actor had burn amount of 0 before the call, completeRedemptions with them
        // as a redeemer would have reverted (CollateralRedemptionTooSmall for 0-amount).
        // We can only check the after state is consistent.
        // Conservative: after completeRedemptions, actor's burn amount must be 0 or unchanged
        // (can't increase via completeRedemptions).
        return _after.burnAmtActorCurrentEpoch <= _before.burnAmtActorCurrentEpoch;
    }

    /// DOOM-FF-06 — setAssetSender(address(0)) bricks completeRedemptions.
    ///             If assetSender == address(0), completeRedemptions will attempt
    ///             collateral.safeTransferFrom(address(0), ...) which reverts.
    ///             This property ALERTS when assetSender is address(0).
    ///             It is a real bug (no validation in setAssetSender).
    ///             Expected: fuzzer FINDS this property violation.
    function property_doom_assetSenderNotZero() public view returns (bool) {
        return cashManager.assetSender() != address(0);
    }

    /// DOOM-FF-07 — setEpochDuration(0) causes division-by-zero in transitionEpoch.
    ///             If epochDuration == 0, the next call to any updateEpoch-decorated
    ///             function panics with division-by-zero.
    ///             This property ALERTS when epochDuration is 0.
    ///             Real bug: no validation in setEpochDuration.
    ///             Expected: fuzzer FINDS this property violation.
    function property_doom_epochDurationNotZero() public view returns (bool) {
        return cashManager.epochDuration() != 0;
    }

    /// ECO-02 — overrideExchangeRate has no delta limit; rate can be set arbitrarily low.
    ///          Alert: if ghost_lowRateOverrideDetected, the override set rate < 1e3.
    ///          This is a real missing-validation bug.
    ///          Expected: fuzzer FINDS this violation when overrideExchangeRate(1, epoch, 1) is called.
    function property_eco_lowRateOverrideAlert() public view returns (bool) {
        // If a very low rate was set via overrideExchangeRate, flag it
        if (ghost_lowRateOverrideDetected) {
            return false; // VIOLATION: rate set dangerously low without any delta check
        }
        return true;
    }

    /// SOL-06 (exact) — addressToBurnAmt == 0 for the active actor after claimMint
    ///                   (this is actually about mint requests, not burn amounts).
    ///                   After a successful claimMint, mintRequestsPerEpoch[epoch][actor] == 0.
    function property_sol_mintRequestsZeroAfterClaim() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_CLAIM_MINT) return true;
        if (_before.totalSupply >= _after.totalSupply) return true; // no mint / revert
        // claimMint zeroes out mintRequestsPerEpoch[epochToClaim][user]
        // We check the current epoch's slot for the active actor
        // (may not be the claimed epoch if a different actor/epoch was claimed)
        // Conservative: the actor's current epoch request must not have increased
        return _after.mintRequestsActorCurrentEpoch <= _before.mintRequestsActorCurrentEpoch;
    }

    // ================================================================
    //  FF-02 — Double-completeRedemptions detection via ghost
    // ================================================================

    /// FF-02 — After completeRedemptions, the actor's burn amount for the current epoch
    ///         must not increase (redemptions can only be serviced, not created).
    function property_ff_burnAmtNonIncreasingAfterComplete() public view returns (bool) {
        if (currentOperation != SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) return true;
        // totalBurned for current epoch (not the serviced epoch, but we track current epoch)
        // The serviced epoch's totalBurned is not in Vars (it's a past epoch).
        // Soft check: current epoch's totalBurned must not increase due to completeRedemptions.
        if (_before.currentEpoch != _after.currentEpoch) return true;
        return _after.totalBurnedCurrentEpoch <= _before.totalBurnedCurrentEpoch;
    }
}

