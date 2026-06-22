# Dataflow Taint Analysis

---

## Summary Table

| Function | Contract | Taint Level | Exploitability Score | Sources | Sinks | Max Depth |
|---|---|---|---|---|---|---|
| requestMint | CashManager | HIGH | 8/10 | collateralAmountIn (user), msg.sender | mintRequestsPerEpoch, collateral.transferFrom, currentMintAmount | 3 |
| claimMint | CashManager | HIGH | 9/10 | user (caller-controlled), epochToClaim | cash.mint(user, cashOwed), mintRequestsPerEpoch cleared | 4 |
| setMintExchangeRate | CashManager | HIGH | 9/10 | exchangeRate (admin), epochToSet | epochToExchangeRate, lastSetMintExchangeRate, _pause() | 2 |
| overrideExchangeRate | CashManager | HIGH | 10/10 | correctExchangeRate, epochToSet, _lastSetMintExchangeRate (all admin) | epochToExchangeRate, lastSetMintExchangeRate (both writeable, no delta check) | 2 |
| completeRedemptions | CashManager | HIGH | 8/10 | redeemers[], fees, collateralAmountToDist (all admin) | collateral.transferFrom(assetSender->redeemer), cash.mint (refund), redemptionInfo | 5 |
| requestRedemption | CashManager | HIGH | 7/10 | amountCashToRedeem (user) | redemptionInfoPerEpoch, cash.burnFrom, currentRedeemAmount | 3 |
| setPrice | OndoPriceOracleV2 | HIGH | 8/10 | price (admin, unbounded) | fTokenToUnderlyingPrice[fToken] → downstream Comptroller borrow capacity | 1 |
| mint (cToken) | CCashDelegate | HIGH | 9/10 | mintAmount (user) | accountTokens, totalSupply, underlying.transferFrom, accrueInterest | 5 |
| borrow (cToken) | CCashDelegate | HIGH | 9/10 | borrowAmount (user) | accountBorrows, totalBorrows, underlying transfer to borrower | 5 |
| seize (cToken) | CCashDelegate | HIGH | 8/10 | seizeTokens (admin-driven liquidation) | accountTokens[liquidator/borrower], totalReserves (protocol fee) | 4 |
| transferFrom (CASH) | CashKYCSenderReceiver | MEDIUM | 5/10 | src, dst, amount | balances, allowances; blocked by KYC hook | 2 |
| addKYCAddresses | KYCRegistry | MEDIUM | 6/10 | addresses[] (role-gated) | kycState — gates all KYC-dependent operations | 1 |
| removeKYCAddresses | KYCRegistry | HIGH | 7/10 | addresses[] (role-gated) | kycState = false → DoS all KYC-gated functions for those addresses | 1 |
| setPriceCap | OndoPriceOracleV2 | MEDIUM | 4/10 | value (admin) | fTokenToUnderlyingPriceCap → caps getUnderlyingPrice | 1 |
| setMintFee | CashManager | MEDIUM | 5/10 | _mintFee (admin, 0..9999) | mintFee → applied in every requestMint fee calculation | 1 |
| transitionEpoch | CashManager | LOW | 2/10 | block.timestamp | currentEpoch, currentEpochStartTimestamp, currentMintAmount=0, currentRedeemAmount=0 | 1 |
| approve (cToken) | CCashDelegate | LOW | 1/10 | spender, amount | transferAllowances only; no external calls | 1 |

---

## HIGH_TAINT Function Details

### CashManager.requestMint
**Taint Level:** HIGH
**Exploitability Score:** 8/10

**Sources:**
- `collateralAmountIn` — user-supplied, determines fee and deposit value.
- `msg.sender` — controls which epoch slot accumulates (`mintRequestsPerEpoch[currentEpoch][msg.sender]`).
- `block.timestamp` (via `updateEpoch` modifier) — transitioning epochs resets currentMintAmount, enabling repeated minting up to limit per epoch.

**Sinks:**
- `mintRequestsPerEpoch[currentEpoch][msg.sender] += depositValueAfterFees` — state that claimMint reads.
- `collateral.safeTransferFrom(msg.sender, feeRecipient, feesInCollateral)` — external call; transfers user tokens.
- `collateral.safeTransferFrom(msg.sender, assetRecipient, depositValueAfterFees)` — external call.
- `currentMintAmount` — updated; rate-limiting state.

**Taint Flow:**
1. `collateralAmountIn` → `_getMintFees(collateralAmountIn)` → `feesInCollateral` (arithmetic, no overflow with uint256).
2. `depositValueAfterFees = collateralAmountIn - feesInCollateral` → `_checkAndUpdateMintLimit(depositValueAfterFees)`.
3. Both `feesInCollateral` and `depositValueAfterFees` flow into external `safeTransferFrom` calls.
4. `depositValueAfterFees` persisted in `mintRequestsPerEpoch`.

**Key vulnerability surface:** `mintFee = 0` means all collateral flows to `assetRecipient = address(this)`. With `assetRecipient` aliased to admin, fee setting can redirect 100% of deposits.

---

### CashManager.claimMint
**Taint Level:** HIGH
**Exploitability Score:** 9/10

**Sources:**
- `user` — caller-supplied; the function mints CASH to `user`, not `msg.sender`. Any KYC'd address can trigger a claim on behalf of another KYC'd address.
- `epochToClaim` — selects which epoch's stored collateral and exchange rate to use.
- `epochToExchangeRate[epochToClaim]` — admin-set value that determines conversion ratio.

**Sinks:**
- `cash.mint(user, cashOwed)` — external call; inflates CASH supply and sends to user.
- `mintRequestsPerEpoch[epochToClaim][user] = 0` — clears the claim (prevents double-claim).

**Taint Flow:**
1. `epochToClaim` → `mintRequestsPerEpoch[epochToClaim][user]` lookup → `collateralDeposited`.
2. `collateralDeposited` + `epochToExchangeRate[epochToClaim]` → `_getMintAmountForEpoch` → `cashOwed`.
3. `cashOwed` flows into `cash.mint(user, cashOwed)`.

**Key vulnerability surface:** If `epochToExchangeRate[epochToClaim]` is manipulated (via `overrideExchangeRate`), `cashOwed` can be 0 (rate too high → user loses collateral with no CASH) or astronomically large (rate near 0 → unlimited CASH inflation).

---

### CashManager.setMintExchangeRate
**Taint Level:** HIGH
**Exploitability Score:** 9/10

**Sources:**
- `exchangeRate` — SETTER_ADMIN-supplied, 6-decimal fixed-point rate.
- `epochToSet` — which epoch to price.

**Sinks:**
- `epochToExchangeRate[epochToSet] = exchangeRate` — directly determines claimMint payout.
- `lastSetMintExchangeRate = exchangeRate` — anchors future delta checks.
- `_pause()` — auto-triggered if delta > `exchangeRateDeltaLimit` bps.

**Taint Flow:**
1. `exchangeRate` → delta check against `lastSetMintExchangeRate`.
2. If delta <= limit: `epochToExchangeRate[epochToSet] = exchangeRate`, `lastSetMintExchangeRate = exchangeRate`.
3. If delta > limit: `epochToExchangeRate[epochToSet] = exchangeRate` (rate is stored anyway!), then `_pause()`.
4. Note: even in the pause path, the rate is written — users can claimMint at the suspicious rate once unpaused.

**Key vulnerability surface:** SETTER_ADMIN can write any rate to any past epoch (if not already set). Combined with the auto-pause on extreme values being bypassable via `overrideExchangeRate` by MANAGER_ADMIN, the effective check is not a hard safety limit.

---

### CashManager.completeRedemptions
**Taint Level:** HIGH
**Exploitability Score:** 8/10

**Sources:**
- `redeemers[]`, `refundees[]` — admin-supplied; KYC-checked inside function.
- `collateralAmountToDist` — admin-supplied; total collateral to distribute.
- `fees` — admin-supplied; extracted before distribution.
- `epochToService` — which epoch to service.

**Sinks:**
- `collateral.safeTransferFrom(assetSender, redeemer, collateralAmountDue)` for each redeemer.
- `collateral.safeTransferFrom(assetSender, feeRecipient, fees)`.
- `cash.mint(refundee, cashAmountBurned)` for each refundee.
- `redemptionInfoPerEpoch[epochToService].addressToBurnAmt[*] = 0` — clears burn records.

**Taint Flow:**
1. `fees` subtracted from `collateralAmountToDist` → `amountToDist`.
2. `_processRefund(refundees, epochToService)` → refunds burned CASH, returns `refundedAmt`.
3. `quantityBurned = totalBurned - refundedAmt`.
4. `_processRedemption`: for each redeemer, `collateralAmountDue = (amountToDist * cashAmountReturned) / quantityBurned`.
5. Integer division in step 4 can result in 0 if individual amounts are small relative to `quantityBurned`.

**Key vulnerability surface:** Admin can set `fees = collateralAmountToDist - epsilon`, leaving epsilon for all redeemers. Combined with a large `quantityBurned`, individual `collateralAmountDue` rounds to 0 → revert `CollateralRedemptionTooSmall` for all redeemers (DoS on redemptions). Alternatively, admin can omit redeemers from the list entirely (they can be processed in a future call, but unchecked ordering risk exists).

---

### OndoPriceOracleV2.setPrice
**Taint Level:** HIGH
**Exploitability Score:** 8/10

**Sources:**
- `fToken` — the token whose price is set.
- `price` — owner-supplied, uint256, no upper bound, no lower bound beyond requiring OracleType.MANUAL.

**Sinks:**
- `fTokenToUnderlyingPrice[fToken]` — read by `getUnderlyingPrice` → consumed by Comptroller for borrow capacity.

**Downstream taint (coverage phase):**
- `getUnderlyingPrice` → `Comptroller.getAccountLiquidity` → `borrowAllowed` → `borrow` → `accountBorrows`, `totalBorrows`.
- A price of 0 → collateral worth nothing → all borrows instantly liquidatable.
- A price of type(uint256).max → collateral worth max → unlimited borrowing.

---

### CCashDelegate / CTokenDelegate: mint, borrow, seize
**Taint Level:** HIGH (all three)
**Exploitability Score:** 9/10 (mint, borrow), 8/10 (seize)

**mint(uint256 mintAmount):**
- Source: `mintAmount` (user), oracle price (admin via setPrice).
- Sink: `accountTokens[minter]`, `totalSupply`, `underlying.transferFrom(minter, this, mintAmount)`.
- Taint path: mintAmount → `mintFresh` → Comptroller.mintAllowed → underlying transfer → cToken balance update.
- Exchange rate computed from (totalCash + totalBorrows - totalReserves) / totalSupply; first mint anchors the rate.

**borrow(uint256 borrowAmount):**
- Source: `borrowAmount` (user), `getUnderlyingPrice` (admin-influenced).
- Sink: `accountBorrows[borrower].principal`, `totalBorrows`, `underlying.transfer(borrower, borrowAmount)`.
- Taint path: borrowAmount → accrueInterest → `borrowFresh` → Comptroller.borrowAllowed (checks price-based liquidity) → underlying transfer.
- Oracle manipulation directly enables oversized borrows.

**seize(address liquidator, address borrower, uint256 seizeTokens):**
- Source: `seizeTokens` (called by liquidateBorrow path, which is called from another cToken's liquidateBorrow).
- Sink: `accountTokens[borrower] -= seizeTokens * (1 - protocolSeizeShareMantissa)`, `accountTokens[liquidator] += seize amount`, `totalReserves += protocol portion`.
- Note: seize can only be called by another cToken (comptroller checks caller), not directly by users.

