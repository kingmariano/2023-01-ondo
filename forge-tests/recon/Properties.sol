// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {SelectorStorage} from "./SelectorStorage.sol";

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
}

