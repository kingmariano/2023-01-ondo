# Economic Oracle Identification

Scan of the 9 vulnerability classes for the Ondo CASH + Flux/Compound lending protocol.

---

## APPLICABLE: ORACLE_MANIPULATION

**Contracts/Functions:**
- OndoPriceOracleV2.setPrice(fToken, price) — manual price set by owner
- OndoPriceOracleV2.getUnderlyingPrice(fToken) — reads from any of 3 oracle paths
- CashManager.epochToExchangeRate[epoch] — set by SETTER_ADMIN; used to compute CASH minted

**Economic Invariant:**
The exchange rate in CashManager determines how much CASH is minted per unit of collateral.
A manipulated or incorrectly set exchange rate means users receive more or fewer CASH tokens
than the NAV of the underlying assets warrants.

**Attack Vector:**
1. SETTER_ADMIN sets a very low exchangeRate (e.g. 1) via setMintExchangeRate, causing
   claimMint to mint far more CASH than collateral deposited justifies.
2. MANAGER_ADMIN uses overrideExchangeRate to retroactively set an incorrect rate for
   a past epoch, over-minting CASH for claimers of that epoch.
3. OndoPriceOracleV2: if Chainlink oracle data becomes stale (timestamp drift),
   getChainlinkOraclePrice could return an outdated price.
4. OndoPriceOracleV2: MANUAL path price can be set arbitrarily by owner.

**Monitoring Variables:**
- epochToExchangeRate[epoch] — must be within delta of lastSetMintExchangeRate
- lastSetMintExchangeRate — must not drift far from market price
- fTokenToUnderlyingPrice[fToken] — must reflect true market price
- maxChainlinkOracleTimeDelay — must be short enough to prevent stale prices

**Prerequisites:**
- SETTER_ADMIN or MANAGER_ADMIN key compromise (for CashManager)
- Owner key compromise (for OndoPriceOracleV2)

---

## APPLICABLE: SHARE_INFLATION

**Contracts/Functions:**
- CashManager._getMintAmountForEpoch — cashOwed = (collateralDeposited * decimalsMultiplier * 1e6) / exchangeRate
- CashManager.claimMint — issues CASH via cash.mint
- CashManager._processRefund — re-mints CASH to refundees

**Economic Invariant:**
Total CASH minted across all epochs should not exceed the collateral value deposited
adjusted by the exchange rate.

**Attack Vector:**
1. If exchangeRate is set to 1 (near-zero), cashOwed becomes astronomically large.
2. In _processRefund: cash.mint(refundee, cashAmountBurned) — if totalBurned is
   manipulated via setPendingRedemptionBalance, refund amounts can be inflated.
3. Repeated calls to claimMint would only work if mintRequestsPerEpoch is not zeroed —
   it is zeroed before mint (safe as written).

**Monitoring Variables:**
- totalSupply of CashKYCSenderReceiver vs sum of all claimMint amounts
- Sum of mintRequestsPerEpoch[epoch][user] after claiming should be 0
- redemptionInfoPerEpoch[epoch].totalBurned must equal sum of addressToBurnAmt

**Prerequisites:**
- SETTER_ADMIN manipulating exchangeRate
- MANAGER_ADMIN manipulating setPendingRedemptionBalance

---

## APPLICABLE: FEE_EXTRACTION

**Contracts/Functions:**
- CashManager.requestMint — charges _getMintFees(collateralAmountIn) to feeRecipient
- CashManager.completeRedemptions — transfers fees from assetSender to feeRecipient
- CashManager.setMintFee — sets fee in basis points (max < BPS_DENOMINATOR = 9999 bps)

**Economic Invariant:**
Fees collected should equal collateralAmount * mintFee / BPS_DENOMINATOR.
The fees parameter in completeRedemptions has no on-chain validation against burned CASH.

**Attack Vector:**
1. MANAGER_ADMIN raises mintFee to 9999 before a large deposit.
2. MANAGER_ADMIN sets feeRecipient to attacker-controlled address.
3. In completeRedemptions: fees parameter is admin-controlled with no ceiling check.

**Monitoring Variables:**
- mintFee — should not change unexpectedly
- feeRecipient — should not change unexpectedly
- fees in completeRedemptions vs burned collateral value

**Prerequisites:**
- MANAGER_ADMIN role compromise

---

## APPLICABLE: PRECISION_ACCUMULATION

**Contracts/Functions:**
- CashManager._getMintAmountForEpoch: cashOwed = amountE24 / epochToExchangeRate[epoch]
  Integer division truncates small deposits.
- CashManager._getMintFees: fees = (collateralAmount * mintFee) / BPS_DENOMINATOR
  Rounds down for small amounts (protected by minimumDepositAmount >= BPS_DENOMINATOR).
- CashManager._processRedemption: collateralAmountDue = (amountToDist * cashAmountReturned) / quantityBurned
  Rounds down; reverts if collateralAmountDue == 0 (CollateralRedemptionTooSmall).
- CTokenCash.exchangeRateStoredInternal: precision loss over many accrual periods.

**Economic Invariant:**
Sum of individual redemption payouts should approximately equal total distributed collateral.
Rounding dust should not accumulate to material value.

**Attack Vector:**
1. Many small mint requests cause per-user CASH rounding down.
2. In completeRedemptions with many small redeemers, individual payouts round to 0 causing revert.
3. Accumulated interest accrual rounding in cToken exchange rate.

**Monitoring Variables:**
- Sum of cashOwed across all claimMint calls vs total collateral deposits
- Sum of collateralAmountDue in completeRedemptions vs amountToDist

**Prerequisites:**
- No special access; emerges from arithmetic with specific input combinations

---

## APPLICABLE: COLLATERAL_RATIO_VIOLATION (Partial — Lending Unreachable)

**Contracts/Functions:**
- CCashDelegate.borrow / liquidateBorrow (UNREACHABLE — bare delegate)
- OndoPriceOracleV2.getUnderlyingPrice — feeds Comptroller collateral valuation

**Economic Invariant:**
Borrowers must maintain sufficient collateral to cover debt. Comptroller uses oracle prices.
If prices are manipulated, under-collateralized borrows become possible.

**Attack Vector:**
1. Owner sets artificially high price for collateral fToken via setPrice (MANUAL).
2. Price cap removal allows price to be inflated beyond true market value.

**Monitoring Variables:**
- fTokenToUnderlyingPrice[fToken] vs external market prices
- Borrower liquidity after each price change

**Prerequisites:**
- Owner key compromise; lending market wired (currently UNREACHABLE)

---

## NOT APPLICABLE: AMM_INVARIANT_VIOLATION
No swap/liquidity pool/AMM. Protocol is an epoch-based vault + lending market.

## NOT APPLICABLE: SLIPPAGE_MANIPULATION
No swap operations. Exchange rate is admin-set per epoch, not market-driven.

## NOT APPLICABLE: FLASH_LOAN_ARBITRAGE
No flash loan functionality in any in-scope contract.

## NOT APPLICABLE: GOVERNANCE_MANIPULATION
No on-chain governance. Access control is role-based (OpenZeppelin AccessControl).

---

## Summary Table

| Vulnerability Class | Applicable | Severity | Gating Requirement |
|---------------------|-----------|----------|-------------------|
| ORACLE_MANIPULATION | YES | HIGH | SETTER_ADMIN/owner key |
| SHARE_INFLATION | YES | HIGH | SETTER_ADMIN/MANAGER_ADMIN key |
| FEE_EXTRACTION | YES | MEDIUM | MANAGER_ADMIN key |
| PRECISION_ACCUMULATION | YES | LOW-MEDIUM | None (arithmetic) |
| COLLATERAL_RATIO_VIOLATION | PARTIAL | HIGH | Owner key; market wiring needed |
| AMM_INVARIANT_VIOLATION | NO | — | — |
| SLIPPAGE_MANIPULATION | NO | — | — |
| FLASH_LOAN_ARBITRAGE | NO | — | — |
| GOVERNANCE_MANIPULATION | NO | — | — |
