# Properties — Second Pass (reviewed & filtered)

## INFRASTRUCTURE STATUS

- Ghost infrastructure present: **MINIMAL / STUB ONLY**. `BeforeAfter.sol` has an empty `Vars` struct with only a `__ignore__` placeholder, empty `__before()` / `__after()` bodies, and no ghost variables. `Properties.sol` is an empty abstract contract extending `BeforeAfter`. No ghost vars, no ProfitTracker, no per-actor accumulators, no snapshot fields exist yet.
- updateGhosts on target functions: **PARTIALLY PRESENT**. The four shortcut handlers (`shortcut_warpAndTransitionEpoch`, `shortcut_fullMintCycle`, `shortcut_mintCashThenRequestRedemption`, `shortcut_pauseAndMultiexcall`) carry `updateGhosts`. All auto-generated handlers use `trackOp(...)` which also calls `__before`/`__after`, but those bodies are empty. No state-changing handler currently populates ghost vars because `__before`/`__after` are stubs.
- Phase 3A MUST:
  1. Add ghost vars to `Vars` struct: `totalSupply`, `cashBalanceActor`, `mintRequestsActor`, `burnAmtActor`, `totalBurned_epoch`, `currentEpoch`, `currentMintAmount`, `currentRedeemAmount`, `epochToExchangeRate_e`, `lastSetMintExchangeRate`, `paused`, `collateralBalanceActor`, `kycStatus_actor`
  2. Populate `__before()` / `__after()` to snapshot these for the active actor/epoch
  3. Add a `ProfitTracker` accumulator: `ghost_totalCollateralDeposited`, `ghost_totalCashMinted`, `ghost_totalCashBurned`, `ghost_totalCashRefunded`, `ghost_sumCollateralPaid` (per epoch)
  4. Add per-epoch accumulators keyed by `epochToService` for ROUND-04 / ECO-08 / PROFIT-02

- INFRASTRUCTURE_REQUIRED list (properties that cannot be implemented until Phase 3A ghosts exist):
  - PROFIT-01, PROFIT-02, PROFIT-05 (ProfitTracker accumulators)
  - SOL-01 (ghost mint/burn/refund accumulators)
  - ROUND-04, ECO-08 (per-epoch sumPaid accumulator)
  - T12-03 (per-epoch per-user burn accumulator)
  - T13-02 (ghost totalSupply = sumBalances)
  - KYC-01 (all-holder enumeration — needs actor set or balance accumulator)
  - LIQ-02 (lending phase ghost delta — deferred)

---

### Target Function Classification

| Handler | Contract | Modifier | Ghost Category | Stale-Op Risk | Notes |
|---------|----------|----------|----------------|---------------|-------|
| cashManager_requestMint | CashManager | asActor + trackOp | A | NO | Standard deposit; snapshots: mintRequests, currentMintAmount, collateralBalance |
| cashManager_claimMint | CashManager | asActor + trackOp | A | NO | Snapshots: cashBalance, mintRequests→0, totalSupply |
| cashManager_requestRedemption | CashManager | asActor + trackOp | A | NO | Snapshots: burnAmt, totalBurned, totalSupply |
| cashManager_transitionEpoch | CashManager | asActor + trackOp | B | YES — STALE_OP_RISK | Advances epoch; invalidates rate/limit snapshots; must reset rate/epoch ghosts |
| shortcut_warpAndTransitionEpoch | CashManager | updateGhosts | B | YES — STALE_OP_RISK | vm.warp + transitionEpoch; epoch/time advance; ghost reset required |
| shortcut_fullMintCycle | CashManager | updateGhosts | B | YES — STALE_OP_RISK | Multi-step: requestMint + warp + setRate + claimMint; epoch changes mid-call |
| shortcut_mintCashThenRequestRedemption | CashManager | updateGhosts | A | NO | Admin mint + requestRedemption; snapshots: burnAmt, totalSupply |
| shortcut_pauseAndMultiexcall | CashManager | updateGhosts | B | NO | Pause state flip; snapshot: paused flag |
| cashManager_completeRedemptions | CashManager | asAdmin + trackOp | A | NO | Snapshots: burnAmts→0, collateralBalance, totalSupply (refund path) |
| cashManager_overrideExchangeRate | CashManager | asAdmin + trackOp | B | YES — STALE_OP_RISK | Overrides rate for any epoch; invalidates rate-dependent snapshots |
| cashManager_setMintExchangeRate | CashManager | asAdmin + trackOp | B | YES — STALE_OP_RISK | Sets rate + may auto-pause; snapshot: rate, lastSetRate, paused |
| cashManager_pause | CashManager | asAdmin + trackOp | C | NO | Admin config; snapshot: paused flag only |
| cashManager_unpause | CashManager | asAdmin + trackOp | C | NO | Admin config; snapshot: paused flag only |
| cashManager_setMintFee | CashManager | asAdmin + trackOp | C | NO | Param change; no tracked invariant snapshot needed |
| cashManager_setMintLimit | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setRedeemLimit | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setMinimumDepositAmount | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setRedeemMinimum | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setEpochDuration | CashManager | asAdmin + trackOp | C | YES — STALE_OP_RISK | Duration change takes effect at next transitionEpoch; div-by-zero risk if set to 0 |
| cashManager_setMintExchangeRateDeltaLimit | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setAssetSender | CashManager | asAdmin + trackOp | C | NO | Param change; FF-06 risk if set to address(0) |
| cashManager_setAssetRecipient | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setFeeRecipient | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setPendingMintBalance | CashManager | asAdmin + trackOp | A | NO | Admin override of mintRequests; snapshot needed |
| cashManager_setPendingRedemptionBalance | CashManager | asAdmin + trackOp | A | NO | Admin override of burnAmt/totalBurned; snapshot needed |
| cashManager_multiexcall | CashManager | asAdmin + trackOp | B | NO | Arbitrary calls; only callable when paused |
| cashManager_setKYCRegistry | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_setKYCRequirementGroup | CashManager | asAdmin + trackOp | C | NO | Param change |
| cashManager_grantRole | CashManager | asAdmin + trackOp | C | NO | Access control change |
| cashManager_revokeRole | CashManager | asAdmin + trackOp | C | NO | Access control change |
| cashManager_renounceRole | CashManager | asActor + trackOp | C | NO | Access control change |
| kYCRegistry_addKYCAddresses | KYCRegistry | asAdmin + trackOp | A | NO | Snapshot: kycStatus for affected addresses |
| kYCRegistry_removeKYCAddresses | KYCRegistry | asAdmin + trackOp | A | NO | Snapshot: kycStatus; mid-flow removal causes FF-05 risk |
| kYCRegistry_assignRoletoKYCGroup | KYCRegistry | asAdmin + trackOp | C | NO | Param change |
| kYCRegistry_grantRole | KYCRegistry | asAdmin + trackOp | C | NO | Access control |
| kYCRegistry_revokeRole | KYCRegistry | asAdmin + trackOp | C | NO | Access control |
| kYCRegistry_addKYCAddressViaSignature | KYCRegistry | asActor + trackOp | A | NO | Snapshot: kycStatus; sig path |
| shortcut_kycViaSignature | KYCRegistry | updateGhosts | A | NO | Exercises EIP-712 ECDSA path |
| ondoPriceOracleV2_setPrice | OndoPriceOracleV2 | asAdmin + trackOp | B | YES — STALE_OP_RISK | Price change; invalidates collateral-ratio snapshots for lending phase |
| ondoPriceOracleV2_setPriceCap | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | Cap param |
| ondoPriceOracleV2_setOracle | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | Oracle address param |
| ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | Staleness threshold |
| ondoPriceOracleV2_setFTokenToCToken | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | REVERTS in base setup (coverage phase) |
| ondoPriceOracleV2_setFTokenToChainlinkOracle | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | REVERTS in base setup (coverage phase) |
| ondoPriceOracleV2_transferOwnership | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | Owner change |
| ondoPriceOracleV2_renounceOwnership | OndoPriceOracleV2 | asAdmin + trackOp | C | NO | Owner change — dangerous if called |
| cashKYCSenderReceiver_transfer | CashKYCSenderReceiver | asActor + trackOp | A | NO | Snapshot: balances of from/to |
| cashKYCSenderReceiver_transferFrom | CashKYCSenderReceiver | asActor + trackOp | A | NO | Snapshot: balances, allowance |
| cashKYCSenderReceiver_approve | CashKYCSenderReceiver | asActor + trackOp | C | NO | Allowance only |
| cashKYCSenderReceiver_burn | CashKYCSenderReceiver | asActor + trackOp | A | NO | Snapshot: balance, totalSupply |
| cashKYCSenderReceiver_burnFrom | CashKYCSenderReceiver | asActor + trackOp | A | NO | Snapshot: balance, allowance, totalSupply |
| cashKYCSenderReceiver_mint | CashKYCSenderReceiver | asAdmin + trackOp | A | NO | Admin mint; snapshot: balance, totalSupply |
| cashKYCSenderReceiver_pause | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Token pause |
| cashKYCSenderReceiver_unpause | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Token unpause |
| cashKYCSenderReceiver_grantRole | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Access control |
| cashKYCSenderReceiver_revokeRole | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Access control |
| cashKYCSenderReceiver_setKYCRegistry | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Param change |
| cashKYCSenderReceiver_setKYCRequirementGroup | CashKYCSenderReceiver | asAdmin + trackOp | C | NO | Param change |
| cashKYCSenderReceiver_initialize | CashKYCSenderReceiver | asActor + trackOp | C | NO | Will revert (already initialized) |
| cCashDelegate_* (34 handlers) | CCashDelegate | asAdmin/asActor + trackOp | C | NO | ALL REVERT in base setup; deferred to coverage phase |
| cTokenDelegate_* (34 handlers) | CTokenDelegate | asAdmin/asActor + trackOp | C | NO | ALL REVERT in base setup; deferred to coverage phase |
| shortcut_priceCapPath | OndoPriceOracleV2 | updateGhosts | A | NO | Exercises cap branch; snapshots price before/after cap |
| shortcut_chainlinkOraclePath | OndoPriceOracleV2 | updateGhosts | C | NO | NO-OP stub; deferred to coverage phase |
| switchActor | ManagersTargets | (none) | C | NO | Actor rotation; no ghost needed |
| switch_asset | ManagersTargets | (none) | C | NO | Asset rotation |
| asset_approve | ManagersTargets | asActor + updateGhosts | C | NO | Allowance only |
| asset_mint | ManagersTargets | asAdmin + updateGhosts | A | NO | ERC20 mint to arbitrary address |

---

## Reviewed Property List (refined)

Legend: AP-10 = stale/live snapshot mismatch risk; AP-11 = compound-op ghost invalidation; AP-12 = rounding-direction conflict

---

### PROFIT Group

**PROFIT-01** — Total CASH minted never exceeds collateral deposited converted at epoch rates.
Decision: **KEEP** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — requires multi-epoch accumulation) | Ghost: A (ProfitTracker) | INFRASTRUCTURE_REQUIRED | AP-11: shortcut_fullMintCycle spans epoch boundary — accumulator must not double-count.

**PROFIT-02** — After completeRedemptions, sumPayouts + fees == collateralAmountToDist exactly.
Decision: **KEEP** | Appeal: 4 (per-call arithmetic, fuzzer hits easily once completeRedemptions is reachable) | Ghost: A | INFRASTRUCTURE_REQUIRED (per-call sum accumulator) | AP-12: integer division rounds down, so sum may be strictly less than collateralAmountToDist — property should assert `<=` not `==`.

**PROFIT-03** — Each redeemer's collateral due equals their pro-rata share of totalBurned (rounded down).
Decision: **MERGE into ROUND-03** — identical arithmetic assertion | Ghost: A

**PROFIT-04** — claimMint zeroes mintRequestsPerEpoch before mint; no double-claim.
Decision: **KEEP** | Appeal: 5 (direct post-call storage check; trivially verifiable) | Ghost: A

**PROFIT-05** — Net CASH burned equals net decrease in totalSupply (burns - refunds = supply delta).
Decision: **KEEP** | Appeal: 3 | Ghost: A (ProfitTracker) | INFRASTRUCTURE_REQUIRED | AP-11: shortcut_fullMintCycle may trigger refund path — must track refunds separately.

**PROFIT-06** — epochToExchangeRate[e] is immutable once set except via overrideExchangeRate.
Decision: **MERGE into T12-01** — same invariant stated there | Ghost: B

---

### CANARY Group

**CANARY-01 through CANARY-07** — All seven reachability canaries.
Decision: **KEEP ALL** | Appeal: 5 each (canaries are zero-cost; they confirm fuzzer coverage) | Ghost: C (canary booleans, no snapshot needed) | Note: CANARY-02 requires shortcut_fullMintCycle to fire; CANARY-04 requires completeRedemptions path; CANARY-07 may conflict with AP-10 if epoch snapshot taken before warp.

---

### SOL Group (Solvency / Conservation)

**SOL-01** — totalSupply = ghostMinted - ghostBurned + ghostRefunded at all times.
Decision: **KEEP** | Appeal: 3 | Ghost: A | INFRASTRUCTURE_REQUIRED

**SOL-02** — currentMintAmount <= mintLimit always.
Decision: **KEEP** | Appeal: 5 (direct assert post-requestMint; no ghost needed) | Ghost: A (snapshot currentMintAmount)

**SOL-03** — currentRedeemAmount <= redeemLimit always.
Decision: **KEEP** | Appeal: 5 | Ghost: A

**SOL-04** — After transitionEpoch, currentMintAmount == 0 and currentRedeemAmount == 0.
Decision: **KEEP** | Appeal: 5 | Ghost: B (epoch reset handler) | AP-10: must read AFTER warp/transition, not from stale snapshot.

**SOL-05** — mintRequestsPerEpoch[e][u] == 0 after claimMint.
Decision: **MERGE into PROFIT-04** — same assertion | Ghost: A

**SOL-06** — addressToBurnAmt[addr] == 0 after completeRedemptions for that address.
Decision: **KEEP** | Appeal: 5 (direct storage check) | Ghost: A

---

### HF / LIQ Groups (Health Factor, Liquidation — COVERAGE_PHASE)

**HF-01, HF-02, HF-03, LIQ-01, LIQ-02, LIQ-03** — All six lending properties.
Decision: **DROP (deferred)** — All 34 bare-cToken handlers revert; Comptroller not wired; IRM == address(0). These cannot be exercised in the base setup. Carry forward to coverage phase spec. | Reason: COVERAGE_PHASE — no handler can reach these code paths yet.

---

### MONO Group (Monotonicity)

**MONO-01** — currentEpoch is non-decreasing.
Decision: **KEEP** | Appeal: 5 (ghost_lastEpoch snapshot; assert after every call) | Ghost: B (epoch handlers) | Note: `transitionEpoch` and `shortcut_warpAndTransitionEpoch` are STALE_OP_RISK — ghost_lastEpoch must be updated on B-category handlers too.

**MONO-02** — lastSetMintExchangeRate only changes via setMintExchangeRate or overrideExchangeRate.
Decision: **KEEP** | Appeal: 4 | Ghost: B (rate-setting handlers) | AP-10: stale snapshot from before warp may not reflect current rate — guard with `currentOperation` check.

**MONO-03** — cToken exchangeRateStored non-decreasing. COVERAGE_PHASE.
Decision: **DROP (deferred)** — accrueInterest reverts on bare delegate.

**MONO-04** — redemptionInfoPerEpoch[e].totalBurned is non-decreasing within an epoch.
Decision: **KEEP** | Appeal: 4 | Ghost: A | Note: totalBurned CAN decrease when setPendingRedemptionBalance reduces it — property should only assert for non-admin calls (requestRedemption); admin path is an acknowledged exception.

---

### ROUND Group (Math / Rounding)

**ROUND-01** — _getMintAmountForEpoch rounds down (no over-mint).
Decision: **KEEP** | Appeal: 4 (post-claimMint arithmetic check) | Ghost: A | AP-12: rounding direction confirmed down; fuzzer should hit with small amounts near min deposit.

**ROUND-02** — _getMintFees rounds down (fee never over-collected).
Decision: **KEEP** | Appeal: 4 | Ghost: A | AP-12

**ROUND-03** — _processRedemption rounds down (collateralAmountDue <= pro-rata share).
Decision: **KEEP** (absorbs PROFIT-03) | Appeal: 4 | Ghost: A | AP-12

**ROUND-04** — Sum of collateralAmountDue across redeemers <= amountToDist.
Decision: **KEEP** | Appeal: 3 (NEEDS_SHORTCUT_HANDLER — requires multi-redeemer completeRedemptions) | Ghost: A | INFRASTRUCTURE_REQUIRED (per-call accumulator)

**ROUND-05** — epochToExchangeRate[e] > 0 always after any rate-setting call.
Decision: **KEEP** | Appeal: 5 (direct assert; rate=0 on overrideExchangeRate is a real bug path) | Ghost: B

**ROUND-06** — Rate floor: flag when epochToExchangeRate[e] < 1e3.
Decision: **KEEP as ALERT** | Appeal: 3 | Ghost: B | Note: not a hard revert — implemented as `gte` assertion with a configurable floor constant.

---

### DELTA Group (Variable Transitions)

**DELTA-01** — mintRequestsPerEpoch increases by exactly depositValueAfterFees after requestMint.
Decision: **KEEP** | Appeal: 5 (pre/post snapshot; direct arithmetic) | Ghost: A

**DELTA-02** — totalBurned and addressToBurnAmt increase by exactly amount after requestRedemption.
Decision: **KEEP** | Appeal: 5 | Ghost: A

**DELTA-03** — totalSupply decreases by exactly amount after requestRedemption.
Decision: **KEEP** | Appeal: 5 | Ghost: A

**DELTA-04** — cashBalance increases by exactly cashOwed after claimMint.
Decision: **KEEP** | Appeal: 4 | Ghost: A | AP-12: cashOwed computed with rounding — must use same formula in property.

**DELTA-05** — epochToExchangeRate[epoch] == rate and lastSetMintExchangeRate == rate after successful setMintExchangeRate.
Decision: **KEEP** | Appeal: 4 | Ghost: B | AP-10: property only valid when rate is within delta limit (no auto-pause branch).

**DELTA-06** — paused == true after setMintExchangeRate exceeds delta limit.
Decision: **KEEP** | Appeal: 4 | Ghost: B

**DELTA-07** — currentEpoch increases by floor((t - oldStart) / epochDuration) after transitionEpoch.
Decision: **MERGE into T11-01** — identical content | Ghost: B

---

### RATE Group (Exchange Rate)

**RATE-01** — setMintExchangeRate reverts if epochToSet >= currentEpoch.
Decision: **KEEP** | Appeal: 5 (revert assertion; no ghost needed) | Ghost: C

**RATE-02** — setMintExchangeRate reverts if rate already set for epoch.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**RATE-03** — Rate within delta limit: |newRate - lastSetMintExchangeRate| <= lastRate * deltaLimit / BPS_DENOM.
Decision: **KEEP** | Appeal: 4 | Ghost: B | AP-10: lastSetMintExchangeRate snapshot must be taken before the call.

**RATE-04** — overrideExchangeRate sets rate regardless of delta.
Decision: **KEEP** | Appeal: 5 | Ghost: B

**RATE-05** — claimMint reverts if epochToExchangeRate[epochToClaim] == 0.
Decision: **KEEP** | Appeal: 5 | Ghost: C (pure revert check)

**RATE-06** — getUnderlyingPrice(f) <= priceCap[f] when cap non-zero.
Decision: **KEEP** | Appeal: 4 | Ghost: B (price/cap setters) | COVERAGE_PHASE for Chainlink/Compound paths; MANUAL path testable now via shortcut_priceCapPath.

---

### FEE Group

**FEE-01** — mintFee < BPS_DENOMINATOR always.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**FEE-02** — feesInCollateral + depositValueAfterFees == collateralAmountIn.
Decision: **MERGE into FEE-03** — same assertion | Ghost: A

**FEE-03** — fee split sums to collateralAmountIn exactly (no rounding at split).
Decision: **KEEP** (absorbs FEE-02) | Appeal: 5 (arithmetic identity; no ghost needed) | Ghost: A

**FEE-04** — Fee recipient and asset recipient receive correct amounts.
Decision: **KEEP** | Appeal: 4 (balance delta check) | Ghost: A

**FEE-05** — fees <= collateralAmountToDist in completeRedemptions (no underflow).
Decision: **KEEP** | Appeal: 5 (direct arithmetic guard; real underflow risk) | Ghost: A

**FEE-06** — minimumDepositAmount >= BPS_DENOMINATOR (>= 10_000) always.
Decision: **KEEP** | Appeal: 5 | Ghost: C

---

### DOOM Group

**DOOM-01** — KYC removal post-requestMint: collateral not permanently lost (setPendingMintBalance recovery path).
Decision: **KEEP** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — multi-step: requestMint + removeKYC + setPendingMintBalance) | Ghost: A

**DOOM-02** — requestMint/claimMint/requestRedemption revert when paused.
Decision: **KEEP** | Appeal: 5 | Ghost: C (pause flag check)

**DOOM-03** — completeRedemptions NOT blocked by pause.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**DOOM-04** — requestMint reverts when mintLimit == 0.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**DOOM-05** — requestRedemption reverts when redeemLimit == 0.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**DOOM-06** — overrideExchangeRate(0,...) causes claimMint to revert; collateral locked.
Decision: **KEEP** | Appeal: 4 (tests zero-rate via overrideExchangeRate; real risk per ECO-02) | Ghost: B | AP-10: rate snapshot must be pre-override.

**DOOM-07** — claimMint(nonKYC, epoch) reverts.
Decision: **MERGE into KYC-05** — identical assertion | Ghost: C

---

### PRIV-NEG Group

**PRIV-01 through PRIV-10** — All ten privilege escalation negative tests.
Decision: **KEEP ALL** | Appeal: 5 each (pure revert checks; cheapest properties to implement) | Ghost: C (no snapshot needed) | Note: PRIV-07 (only MANAGER_ADMIN can unpause, not PAUSER_ADMIN) is a subtle but important distinction worth keeping separate.

---

### ECO Group (Economic / Oracle)

**ECO-01** — Auto-pause on delta violation: paused iff last setMintExchangeRate exceeded delta limit.
Decision: **MERGE into DELTA-06** — same assertion | Ghost: B

**ECO-02** — overrideExchangeRate with rate < 1e3: catastrophic inflation risk; flag as critical.
Decision: **KEEP** | Appeal: 3 | Ghost: B | CRITICAL | AP-11: shortcut_fullMintCycle may set rate then override — accumulator must account for which rate is canonical.

**ECO-03** — claimMint: single-claim enforced (mintRequests zeroed before mint).
Decision: **MERGE into PROFIT-04** — identical assertion | Ghost: A

**ECO-04** — _processRefund re-mints exactly addressToBurnAmt (no inflation).
Decision: **KEEP** | Appeal: 4 | Ghost: A

**ECO-05** — fees in completeRedemptions has no on-chain cap; flag when fees > collateralAmountToDist / 2.
Decision: **KEEP as ALERT** | Appeal: 3 (admin risk; fuzz may not trigger unless fees param is large) | Ghost: A | AP-12: boundary is soft (no revert); implement as `lte` with logged violation.

**ECO-06** — mintFee change alert when > 500 bps.
Decision: **KEEP as ALERT** | Appeal: 3 | Ghost: C

**ECO-07** — collateralAmountDue > 0 or revert in _processRedemption (no silent zero payout).
Decision: **MERGE into T14-02** — identical content | Ghost: A

**ECO-08** — sumDue <= amountToDist across all redeemers.
Decision: **MERGE into ROUND-04** — identical assertion | Ghost: A

**ECO-09** — Chainlink staleness causes revert. COVERAGE_PHASE.
Decision: **DROP (deferred)** — requires oracle mock wiring; no Chainlink handler reachable in base setup.

**ECO-10** — Price cap enforced when non-zero.
Decision: **MERGE into RATE-06** — same assertion | Ghost: B

---

### KYC Group

**KYC-01** — All CASH holders are KYC'd: balanceOf(addr) > 0 implies getKYCStatus == true.
Decision: **KEEP** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — requires enumeration over all actors with balance) | Ghost: A | INFRASTRUCTURE_REQUIRED (actor set or balance accumulator)

**KYC-02** — transfer by non-KYC'd initiator reverts.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**KYC-03** — requestMint reverts for non-KYC'd msg.sender.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**KYC-04** — requestRedemption reverts for non-KYC'd msg.sender.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**KYC-05** — claimMint(user, epoch) reverts if user is not KYC'd (absorbs DOOM-07).
Decision: **KEEP** | Appeal: 5 | Ghost: C

**KYC-06** — Sanctioned address blocked at KYC gate.
Decision: **KEEP** | Appeal: 3 | Ghost: C | Note: depends on ISanctionsList mock; verify Setup configures a mock sanctions list.

---

### T11 Group (State Transitions)

**T11-01** — currentEpoch advances by exactly floor((t - oldStart) / epochDuration) (absorbs DELTA-07).
Decision: **KEEP** | Appeal: 4 | Ghost: B | AP-10: snapshot oldStart + oldEpoch BEFORE warp.

**T11-02** — currentEpochStartTimestamp after transitionEpoch is aligned to epoch grid.
Decision: **KEEP** | Appeal: 3 | Ghost: B | AP-10: stale snapshot risk if time warp occurs during compound op.

**T11-03** — setMintExchangeRate delta violation: paused == true AND rate stored, atomically.
Decision: **KEEP** | Appeal: 4 | Ghost: B

**T11-04** — lastSetMintExchangeRate NOT updated when setMintExchangeRate triggers auto-pause.
Decision: **KEEP** | Appeal: 4 | Ghost: B | AP-10: ghost_lastRate snapshot required before call.

**T11-05** — overrideExchangeRate with _lastSetMintExchangeRate == 0 leaves lastSetMintExchangeRate unchanged.
Decision: **KEEP** | Appeal: 3 | Ghost: B | AP-11: compound op (override then transition) could invalidate snapshot.

**T11-06** — setEpochDuration mid-epoch does not change currentEpochStartTimestamp until next transition.
Decision: **KEEP** | Appeal: 3 | Ghost: C | Note: verify by reading currentEpochStartTimestamp before and after setEpochDuration with no transitionEpoch call.

**T11-07** — totalBurned never goes negative; setPendingRedemptionBalance preserves totalBurned >= addressToBurnAmt.
Decision: **KEEP** | Appeal: 3 | Ghost: A | Note: Solidity 0.8 underflow protection already prevents negative; property becomes redundant but worth having as canary if unchecked blocks are added.

**T11-08** — completeRedemptions reverts for current or future epoch.
Decision: **KEEP** | Appeal: 5 | Ghost: C

---

### T12 Group (Valid State)

**T12-01** — epochToExchangeRate[e] once set to non-zero stays non-zero except via overrideExchangeRate (absorbs PROFIT-06).
Decision: **KEEP** | Appeal: 3 | Ghost: B

**T12-02** — mintRequestsPerEpoch[e][u] and addressToBurnAmt[e][u] cannot both be non-zero via normal flows.
Decision: **KEEP as SOFT** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — multi-step; admin paths bypass this; flag rather than assert hard) | Ghost: A

**T12-03** — totalBurned[e] >= sum(addressToBurnAmt[u][e]) for all users.
Decision: **KEEP** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — per-user accumulator required) | Ghost: A | INFRASTRUCTURE_REQUIRED

**T12-04** — kycGroupRoles[group] == 0 maps to DEFAULT_ADMIN_ROLE governance.
Decision: **KEEP** | Appeal: 3 | Ghost: C

**T12-05** — Sanctioned address returns getKYCStatus == false regardless of kycState.
Decision: **MERGE into KYC-06** — same assertion | Ghost: C

**T12-06** — Price cap of 0 means no cap; non-zero cap strictly enforced.
Decision: **MERGE into RATE-06** — identical assertion | Ghost: B

**T12-07** — requestRedemption(0) always reverts even when minimumRedeemAmount == 0.
Decision: **KEEP** | Appeal: 5 | Ghost: C

---

### T13 Group (Peripheral)

**T13-01** — getBurnedQuantity(epoch, user) == redemptionInfoPerEpoch[epoch].addressToBurnAmt[user].
Decision: **KEEP** | Appeal: 5 (view getter vs storage slot; trivial to implement) | Ghost: A

**T13-02** — totalSupply == sum(balanceOf(u)) for all holders.
Decision: **KEEP** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — requires enumeration) | Ghost: A | INFRASTRUCTURE_REQUIRED (actor balance accumulator)

**T13-03** — allowance consumed exactly by transferFrom.
Decision: **KEEP** | Appeal: 5 | Ghost: A

**T13-04** — decimalsMultiplier == 10^(18 - collateral.decimals()); immutable and correct.
Decision: **KEEP** | Appeal: 5 (post-deploy static check; zero ongoing ghost cost) | Ghost: C

**T13-05** — getUnderlyingPrice returns 0 for uninitialized MANUAL fToken (no revert).
Decision: **KEEP** | Appeal: 4 | Ghost: C

**T13-06** — Chainlink scaleFactor computed correctly; no overflow for valid decimals.
Decision: **DROP (deferred)** — setFTokenToChainlinkOracle reverts in base setup (REVERTS entry in reverting-handlers.json); coverage phase only.

---

### T14 Group (Dust)

**T14-01** — cashOwed >= 1 for any deposit >= minimumDepositAmount with sane exchange rate.
Decision: **KEEP** | Appeal: 4 | Ghost: A | AP-12: small deposits near min may round to 0 if rate is very high — this is the invariant to catch.

**T14-02** — Very small addressToBurnAmt triggers CollateralRedemptionTooSmall revert (absorbs ECO-07).
Decision: **KEEP** | Appeal: 3 (NEEDS_SHORTCUT_HANDLER — must set up tiny burn share) | Ghost: A

**T14-03** — _getMintFees(10_000) == 1 when mintFee == 1 (exact rounding verification).
Decision: **KEEP** | Appeal: 4 | Ghost: A | AP-12

**T14-04** — Sequential requestMint calls accumulate correctly in mintRequestsPerEpoch.
Decision: **KEEP** | Appeal: 4 | Ghost: A

**T14-05** — Rounding remainder stays with assetSender; no collateral created.
Decision: **MERGE into ROUND-04** — same bounding assertion | Ghost: A

---

### T15 Group (Bitmap/Flags)

**T15-01** — addKYCAddresses idempotent (double-add); removeKYCAddresses idempotent (double-remove).
Decision: **KEEP** | Appeal: 5 | Ghost: A

**T15-02** — addKYCAddressViaSignature reverts if kycState already true.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**T15-03** — addKYCAddressViaSignature reverts if deadline exceeded.
Decision: **KEEP** | Appeal: 5 (warp past deadline + call) | Ghost: C | AP-10: time warp; snapshot deadline before warp.

**T15-04** — addKYCAddressViaSignature reverts for malformed v (v not 27 or 28).
Decision: **KEEP** | Appeal: 5 | Ghost: C

**T15-05** — getRoleAdmin(PAUSER_ADMIN) == MANAGER_ADMIN; only MANAGER_ADMIN grants/revokes PAUSER_ADMIN.
Decision: **KEEP** | Appeal: 4 | Ghost: C

---

### FF Group (Free-Form Discovery)

**FF-01** — Rate set for epoch with no deposits: non-reverting but permanently wasted slot.
Decision: **KEEP as ALERT** | Appeal: 2 (NEEDS_SHORTCUT_HANDLER — epoch tracking ghost) | Ghost: B

**FF-02** — Second completeRedemptions on already-serviced address reverts (CollateralRedemptionTooSmall).
Decision: **KEEP** | Appeal: 4 (double-service protection; CRITICAL path) | Ghost: A | AP-11: ghost must track serviced-address set.

**FF-03** — transitionEpoch by non-admin cannot brick user operations.
Decision: **KEEP as SOFT** | Appeal: 3 | Ghost: B | Note: `asActor` handler exists for cashManager_transitionEpoch; no DoS expected but worth monitoring.

**FF-04** — multiexcall reverts when not paused; nonReentrant prevents reentrant loops.
Decision: **KEEP** | Appeal: 5 | Ghost: C

**FF-05** — Single non-KYC'd address in redeemers causes full completeRedemptions batch revert.
Decision: **KEEP** | Appeal: 4 (CRITICAL admin operational risk) | Ghost: A | AP-11: must remove KYC after requestRedemption but before completeRedemptions.

**FF-06** — setAssetSender(address(0)) succeeds; subsequent completeRedemptions reverts.
Decision: **KEEP** | Appeal: 4 (MISSING VALIDATION bug) | Ghost: A

**FF-07** — setEpochDuration(0) followed by any updateEpoch-decorated call reverts (division by zero).
Decision: **KEEP** | Appeal: 5 (CRITICAL; MISSING VALIDATION; easy to trigger) | Ghost: B

---

## APPEAL SCORE DISTRIBUTION

| Score | Count | Property IDs |
|-------|-------|-------------|
| 5 | 47 | CANARY-01..07, SOL-02, SOL-03, SOL-04, SOL-06, PRIV-01..10, RATE-01, RATE-02, RATE-04, RATE-05, FEE-01, FEE-03, FEE-05, FEE-06, DOOM-02, DOOM-03, DOOM-04, DOOM-05, KYC-02, KYC-03, KYC-04, KYC-05, T11-08, T12-07, T13-01, T13-03, T13-04, T14-03, T15-01, T15-02, T15-03, T15-04, FF-04, FF-07 |
| 4 | 25 | PROFIT-02, PROFIT-04, ROUND-01, ROUND-02, ROUND-03, ROUND-05, DELTA-01, DELTA-02, DELTA-03, DELTA-05, DELTA-06, RATE-03, RATE-06, FEE-04, DOOM-06, MONO-02, ECO-02 (soft), ECO-04, T11-01, T11-03, T11-04, T13-05, T14-01, FF-02, FF-05, FF-06 |
| 3 | 14 | PROFIT-05, SOL-01, ROUND-06, MONO-04, ECO-05, ECO-06, KYC-06, T11-02, T11-05, T11-06, T11-07, T12-01, T12-04, FF-01, FF-03 |
| 2 | 7 | PROFIT-01, DOOM-01, KYC-01, T12-02, T12-03, T13-02, FF-01 |
| 1 | 0 | (none after merge/drop) |

**NEEDS_SHORTCUT_HANDLER** (appeal ≤ 2 or explicitly flagged):
- PROFIT-01: multi-epoch ProfitTracker accumulation
- DOOM-01: requestMint + removeKYC + setPendingMintBalance sequence
- KYC-01: enumerate all actors with non-zero balance
- T12-02: multi-step mint + redeem same epoch (normal flow)
- T12-03: per-user burn accumulator across all actors in epoch
- T13-02: sum balanceOf over all actors
- FF-01: ghost tracking epochs-with-rate-but-no-deposits
- T14-02: tiny-share setup for CollateralRedemptionTooSmall path

---

## KEEP / DROP / MERGE SUMMARY

| Decision | Count | Notes |
|----------|-------|-------|
| KEEP | 88 | Including ALERTs (soft assertions) and COVERAGE_PHASE-deferred canaries |
| DROP | 7 | HF-01, HF-02, HF-03, LIQ-01, LIQ-02, LIQ-03, ECO-09, MONO-03, T13-06 (all COVERAGE_PHASE; lending not wired) |
| MERGE | 14 | PROFIT-03→ROUND-03, PROFIT-06→T12-01, SOL-05→PROFIT-04, DELTA-07→T11-01, FEE-02→FEE-03, DOOM-07→KYC-05, ECO-01→DELTA-06, ECO-03→PROFIT-04, ECO-07→T14-02, ECO-08→ROUND-04, ECO-10→RATE-06, T12-05→KYC-06, T12-06→RATE-06, T14-05→ROUND-04 |

Total after merge/drop: **88 distinct KEEP properties** (down from 125 raw entries; 7 dropped as unreachable in base setup; 14 collapsed into their canonical equivalents; 30 remaining entries are either ALERTs, soft assertions, or coverage-phase flagged but tracked).

---

## Phase 3A Deferred to Phase 3B (with reasons)

| Property ID | Reason for Deferral |
|-------------|---------------------|
| PROFIT-01 | Multi-epoch ghost accumulator needs ProfitTracker struct with per-epoch per-handler increment; requires shortcut that fires across epoch boundaries |
| PROFIT-02 | Needs per-call sum accumulator inside completeRedemptions reachable by fuzzer; completeRedemptions is reachable but sum tracking requires inline handler instrumentation |
| PROFIT-05 | SOL-01 ghost (netCashBurned = burns - refunds) needs ProfitTracker incremented inside requestRedemption + completeRedemptions; Phase 3B |
| SOL-01 | Same as PROFIT-05; ghost_totalCashMinted / ghost_totalCashBurned / ghost_totalCashRefunded accumulators deferred |
| DELTA-01 | Exact mintRequests delta check: requires knowing `depositValueAfterFees` which depends on `mintFee` at call time; implementable but needs before/after on same-epoch snapshot, which complicates epoch-boundary cases; Phase 3B |
| DELTA-04 | cashOwed exact delta: formula replication safe but requires knowing exact `collateralDeposited` pre-claimMint (stored in snapshot) — implementable but property requires matching epoch exactly; defer to Phase 3B |
| DELTA-05 | Rate exact delta after setMintExchangeRate: works only on non-pausing path; before snapshot of lastSetMintExchangeRate captured, but detecting which path fired (auto-pause vs normal) requires reading paused() delta; Phase 3B |
| DELTA-06 / T11-03 | Auto-pause on delta violation: reading paused() before/after setMintExchangeRate works, but must distinguish from admin-initiated pause(); Phase 3B with currentOperation guard |
| T11-01 / T11-02 | transitionEpoch exact-delta: needs pre-warp timestamp snapshot which is not in Vars (timestamp is block.timestamp in Solidity, accessible but ephemeral); Phase 3B |
| T11-04 | lastSetMintExchangeRate not updated on auto-pause: needs before/after of lastSetMintExchangeRate compared against paused() change; implementable in Phase 3B |
| T11-05 | overrideExchangeRate two-path assertion: needs before snapshot of lastSetMintExchangeRate AND _lastSetMintExchangeRate param visibility; Phase 3B |
| T12-01 | epochToExchangeRate immutability: needs per-epoch ghost tracking which epoch had rate set; Phase 3B ghost map |
| T12-03 | totalBurned >= sum(burnAmt[u]): needs per-actor burn accumulator across all actors; Phase 3B |
| T13-02 | totalSupply == sum(balanceOf): needs actor enumeration; Phase 3B |
| KYC-01 | All holders KYC'd: needs actor enumeration; Phase 3B |
| ROUND-01 | cashOwed rounding down: needs exact cashOwed formula cross-check; Phase 3B |
| ROUND-02 | Fee rounding down: needs fee formula comparison with exact inputs; Phase 3B |
| ROUND-03 / ROUND-04 | Sum due <= amountToDist: needs per-call accumulator inside completeRedemptions inline; Phase 3B |
| RATE-03 | Delta limit arithmetic: needs before snapshot of lastSetMintExchangeRate + rate param visibility; Phase 3B |
| T14-01 | cashOwed >= 1: needs exact _getMintAmountForEpoch formula replication; Phase 3B |
| T14-03 | Exact fee rounding at minimum: needs mintFee==1 guard + exact formula; Phase 3B |
| T14-04 | Sequential requestMint accumulation: needs ghost sum per (epoch, actor); Phase 3B |
| FF-02 | Double-service protection: needs ghost set of serviced addresses; Phase 3B |
| SOL-06 (exact) | addressToBurnAmt == 0 for specific redeemers after completeRedemptions: needs to know which addresses were in the redeemers array; Phase 3B inline |
| ECO-02 | overrideExchangeRate rate < 1e3 alert with pending claims: needs ghost tracking of pending claims per epoch; Phase 3B |
