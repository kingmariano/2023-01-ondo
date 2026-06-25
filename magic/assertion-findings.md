# Assertion-Mode Falsification Campaign — Findings

**Run:** 2026-06-24, `echidna-assertion-long.yaml` (assertion mode, 4 workers,
test-limit 9,999,999). **Outcome:** stopped early (~149k calls) — OOM-killed
during the shrinking phase (4 workers × up to 100k shrink iters × 22
counterexamples in a RAM-limited container). All findings were captured before
the kill; only counterexample *minimization* was lost.

**Headline:** with the properties correctly wired to `t()` (commit `abfa4ad`),
the fuzzer falsified **22 handlers within the first ~149k calls** — versus
**0/280 across a full 10M-call run** when the same properties were inert
`bool` returns. The earlier all-green result was a harness defect, not a clean
protocol.

## 22 falsified handlers ≠ 22 bugs

Echidna attributes a failure to whichever handler's `__after` hook observed a
false invariant. Several invariants are **sticky**: once violated they stay
violated, so every later handler re-trips them and is also marked failed. The 22
handlers collapse to a small number of **distinct invariants**:

| Distinct invariant | Triggering action | Verdict | Evidence |
|---|---|---|---|
| **DOOM-FF-06** `assetSender != 0` | `setAssetSender(address(0))` — no zero-check; bricks `completeRedemptions` (transferFrom from address(0)) | ✅ **Real bug** | `test_doom_assetSenderZero_detectsBug` |
| **DOOM-FF-07** `epochDuration != 0` | `setEpochDuration(0)` — next epoch transition divides by zero | ✅ **Real bug** | `test_doom_epochDurationZero_detectsBug` |
| **ECO-02 / ROUND-06** rate floor | `overrideExchangeRate(low,…)` / `setMintExchangeRate` below `MIN_SAFE_RATE` — override path has no delta limit / floor | ✅ **Real bug** | `test_doom_eco02_lowRateOverride_detectsBug` |
| **SOL-02** `currentMintAmount ≤ mintLimit` | `setMintLimit(x)` with `x < currentMintAmount` | ⚠️ **Property-spec** — legitimate admin lowering of a limit; not a vuln | — |
| **SOL-03** `currentRedeemAmount ≤ redeemLimit` | `setRedeemLimit(x)` with `x < currentRedeemAmount` | ⚠️ **Property-spec** — same pattern, redeem side | — |
| redemption accounting | `setPendingRedemptionBalance*` (admin directly sets burn balances), `fullRedeemCycle`, `mintCashThenRequestRedemption` | ❓ **Needs triage** — likely admin-forced state (spec), possibly accounting fragility | — |

### Falsified handlers, grouped by root-cause invariant
- **DOOM-FF-06:** `cashManager_setAssetSender`
- **DOOM-FF-07:** `cashManager_setEpochDuration`, `cashManager_setEpochDuration_clamped`
- **ECO-02 / ROUND-06:** `cashManager_overrideExchangeRate`, `cashManager_overrideExchangeRate_clamped`, `shortcut_overrideExchangeRate_nonZeroLastRate`, `cashManager_setMintExchangeRate_clamped`, `shortcut_setMintExchangeRate_belowLast_outsideDelta`, `shortcut_setRateThenClaim`
- **SOL-02 (sticky):** `cashManager_setMintLimit`, `cashManager_setMintLimit_clamped`, `shortcut_fullMintCycle`, `cashKYCSenderReceiver_mint`, `cashKYCSenderReceiver_mint_clamped`
- **SOL-03 (sticky):** `cashManager_setRedeemLimit`, `cashManager_setRedeemLimit_clamped`, `shortcut_fullRedeemCycle`
- **redemption accounting:** `cashManager_setPendingRedemptionBalance_clamped`, `shortcut_setPendingRedemptionBalance_increase/decrease/same`, `shortcut_mintCashThenRequestRedemption`

## Confirmed real bugs — minimal reproducers (Foundry, no fuzzer needed)

```solidity
// DOOM-FF-06 — bricks redemptions, no validation
cashManager.setAssetSender(address(0));            // succeeds; should revert

// DOOM-FF-07 — div-by-zero brick on next epoch transition
cashManager.setEpochDuration(0);                   // succeeds; should revert

// ECO-02 / ROUND-06 — exchange rate set far below any sane floor
cashManager.overrideExchangeRate(1, 0, 1);         // lastSetMintExchangeRate = 1
```

All three pass as Foundry unit tests in `CryticToFoundry` (the property returns
`false` / the invariant trips after the call). These are genuine
missing-validation issues in `CashManager`.

## Artifacts
- Full human-readable call sequences for every falsification:
  `magic/assertion-run/echidna-assertion-v2.log` (search `falsified!`).
- 22 raw counterexamples (Echidna JSON corpus form):
  `echidna-assertion-long/reproducers-unshrunk/`.

## Recommended next steps
1. **Fix the 3 real bugs** in `CashManager`: zero-address check in
   `setAssetSender`; non-zero check in `setEpochDuration`; a floor / delta limit
   in `overrideExchangeRate`.
2. **Refine the spec-noise properties** (SOL-02/SOL-03): gate them so a
   deliberate admin limit-decrease isn't counted as a violation (e.g. only
   assert `current ≤ limit` immediately after mint/redeem ops, not after
   `setMintLimit`/`setRedeemLimit`).
3. **Triage the redemption-accounting** falsifications with targeted Foundry
   reproducers to separate admin-forced state from real accounting errors.
4. Re-run a **lean, OOM-safe** campaign (1–2 workers, lower `shrinkLimit`) to
   get clean minimal reproducers once the spec-noise is removed.
