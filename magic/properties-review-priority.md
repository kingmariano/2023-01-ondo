# Properties Review Priority

Functions and contracts are ordered from simplest (fewest dependencies, least storage influence)
to most complex (most external calls, most storage written). Review simpler functions first to
establish baseline invariants, then use those to verify more complex behaviors.

---

## Priority 1 — Leaf / Read-Only Functions (No external calls, no writes)

These functions are pure/view and have no side effects; review first to establish what values
should look like before analyzing state-changing paths.

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 1 | OndoPriceOracleV2 | _min(a, b) | Pure utility; no storage |
| 2 | CashManager | _getMintFees(amount) | Private pure; simple BPS math |
| 3 | CashManager | _scaleUp(amount) | Private view; reads only decimalsMultiplier |
| 4 | CashManager | getBurnedQuantity(epoch, user) | View; reads single mapping slot |
| 5 | KYCRegistry | DOMAIN_SEPARATOR() | View; EIP712 helper |
| 6 | CTokenCash | getBlockNumber() | Internal view; returns block.number |
| 7 | CTokenCash | borrowBalanceStoredInternal | Internal view; reads accountBorrows |
| 8 | CTokenCash | exchangeRateStoredInternal | Internal view; math on totalSupply/totalCash |
| 9 | CTokenCash | borrowBalanceStored | Public view wrapper |
| 10 | CTokenCash | exchangeRateStored | Public view wrapper |
| 11 | CTokenCash | getCash | View; reads getCashPrior |
| 12 | CTokenCash | balanceOf | View; reads accountTokens |
| 13 | CTokenCash | allowance | View; reads transferAllowances |
| 14 | CTokenCash | getAccountSnapshot | View; composite |
| 15 | OndoPriceOracleV2 | getChainlinkOraclePrice | View; reads oracle + Chainlink data |

---

## Priority 2 — Single-Storage Writers with No Cross-Contract Calls

These write to exactly one or two storage variables with no external protocol calls (access
control checks via AccessControl internal logic only).

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 16 | OndoPriceOracleV2 | setPrice | 1 write (fTokenToUnderlyingPrice); onlyOwner |
| 17 | OndoPriceOracleV2 | setFTokenToOracleType | 1 write (fTokenToOracleType); onlyOwner |
| 18 | OndoPriceOracleV2 | setPriceCap | 1 write (fTokenToUnderlyingPriceCap); onlyOwner |
| 19 | OndoPriceOracleV2 | setOracle | 1 write (cTokenOracle); onlyOwner |
| 20 | OndoPriceOracleV2 | setMaxChainlinkOracleTimeDelay | 1 write; onlyOwner |
| 21 | CashManager | setMintFee | 1 write (mintFee); onlyRole(MANAGER_ADMIN) |
| 22 | CashManager | setMinimumDepositAmount | 1 write; onlyRole(MANAGER_ADMIN) |
| 23 | CashManager | setFeeRecipient | 1 write; onlyRole(MANAGER_ADMIN) |
| 24 | CashManager | setAssetRecipient | 1 write; onlyRole(MANAGER_ADMIN) |
| 25 | CashManager | setAssetSender | 1 write; onlyRole(MANAGER_ADMIN) |
| 26 | CashManager | setRedeemMinimum | 1 write; onlyRole(MANAGER_ADMIN) |
| 27 | CashManager | setMintLimit | 1 write; onlyRole(MANAGER_ADMIN) |
| 28 | CashManager | setRedeemLimit | 1 write; onlyRole(MANAGER_ADMIN) |
| 29 | CashManager | setEpochDuration | 1 write; onlyRole(MANAGER_ADMIN) |
| 30 | CashManager | setMintExchangeRateDeltaLimit | 1 write; onlyRole(MANAGER_ADMIN) |
| 31 | CashManager | setKYCRequirementGroup | 1 write via internal; onlyRole(MANAGER_ADMIN) |
| 32 | CashManager | setKYCRegistry | 1 write via internal; onlyRole(MANAGER_ADMIN) |
| 33 | KYCRegistry | assignRoletoKYCGroup | 1 write (kycGroupRoles); REGISTRY_ADMIN |
| 34 | CashKYCSenderReceiver | setKYCRegistry | 1 write; KYC_CONFIGURER_ROLE |
| 35 | CashKYCSenderReceiver | setKYCRequirementGroup | 1 write; KYC_CONFIGURER_ROLE |

---

## Priority 3 — Single Cross-Contract Call, Moderate Storage

These make exactly one meaningful external call to another in-scope contract and write
a moderate number of slots.

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 36 | KYCRegistry | getKYCStatus | 1 external (sanctionsList.isSanctioned); key gate for all flows |
| 37 | KYCRegistry | addKYCAddresses | Loops over addresses; writes kycState[group][addr] |
| 38 | KYCRegistry | removeKYCAddresses | Symmetric to add |
| 39 | OndoPriceOracleV2 | getUnderlyingPrice | Branches over oracle types; calls external oracles |
| 40 | OndoPriceOracleV2 | setFTokenToCToken | Calls underlying() on fToken + cToken (external) |
| 41 | OndoPriceOracleV2 | setFTokenToChainlinkOracle | Calls underlying().decimals() + oracle.decimals() |
| 42 | CTokenCash | approve | 1 write (transferAllowances); no external calls |
| 43 | CashKYCSenderReceiver | approve | ERC20 approve; no KYC check |
| 44 | CTokenCash | transitionEpoch (via accrueInterest) | Multiple writes + IRM call; critical but isolated |

---

## Priority 4 — Multi-Storage Writers with KYC Gate (Core User Flows)

These are the core user-facing flows that touch multiple storage slots AND make KYC checks.
Review after the gates themselves are understood.

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 45 | CashManager | transitionEpoch | 4 writes; critical time-dependent state transition |
| 46 | CashManager | pause / unpause | 1 write; changes paused flag that gates many functions |
| 47 | CashKYCSenderReceiver | _beforeTokenTransfer | KYC calls on 3 addresses; internal hook |
| 48 | CashKYCSenderReceiver | transfer | ERC20 + _beforeTokenTransfer (3 KYC calls); 2 storage writes |
| 49 | CashKYCSenderReceiver | transferFrom | Same as transfer + allowance check |
| 50 | CashKYCSenderReceiver | burn | Burns own tokens; 1 KYC call (sender) |
| 51 | CashKYCSenderReceiver | burnFrom | 3 KYC calls; allowance + balance writes |
| 52 | KYCRegistry | addKYCAddressViaSignature | ECDSA.recover + EIP712; 1 kycState write |

---

## Priority 5 — Epoch-Coupled Multi-Contract Flows (High Complexity)

These depend on epoch state (must call transitionEpoch first), make multiple external calls,
and write to multiple complex mappings.

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 53 | CashManager | requestMint | epoch+KYC+2 safeTransferFrom; reads 5 storage slots |
| 54 | CashManager | setPendingMintBalance | epoch+admin; modifies mint mapping |
| 55 | CashManager | setMintExchangeRate | epoch + conditional pause; delta limit calculation |
| 56 | CashManager | overrideExchangeRate | epoch + exchange rate override |
| 57 | CashManager | requestRedemption | epoch+KYC+cash.burnFrom; writes redemptionInfoPerEpoch |
| 58 | CashManager | setPendingRedemptionBalance | epoch+admin; modifies redemption mapping + totalBurned |

---

## Priority 6 — Full Lifecycle / Multi-Party Flows (Most Complex)

These are the terminal flows that close the mint or redemption cycle. They depend on prior
state from Priority 5 functions, make multiple external token calls, and involve loops over
user arrays.

| # | Contract | Function | Reason |
|---|----------|----------|--------|
| 59 | CashManager | claimMint | Depends on requestMint + setMintExchangeRate; cash.mint call |
| 60 | CashManager | completeRedemptions | Most complex: KYC arrays + _processRefund + _processRedemption + fee transfer; 6+ external calls |
| 61 | CashManager | multiexcall | Arbitrary call surface; only when paused + MANAGER_ADMIN |

---

## Priority 7 — Bare Lending Delegates (BLOCKED; Deferred to Coverage Phase)

All CCashDelegate and CTokenDelegate state-changing functions are currently blocked because
the delegates are deployed bare with admin=address(0) and interestRateModel=address(0).
Document expected behavior but defer detailed invariant analysis until market wiring.

| # | Contract | Function | Blocking Reason |
|---|----------|----------|----------------|
| 62 | CCashDelegate | accrueInterest | IRM = address(0) |
| 63 | CCashDelegate | mint | accrueInterest + comptroller blocked |
| 64 | CCashDelegate | redeem / redeemUnderlying | accrueInterest + comptroller blocked |
| 65 | CCashDelegate | borrow | accrueInterest + comptroller blocked |
| 66 | CCashDelegate | repayBorrow / repayBorrowBehalf | accrueInterest + comptroller blocked |
| 67 | CCashDelegate | liquidateBorrow | accrueInterest + comptroller blocked |
| 68 | CCashDelegate | seize | comptroller.seizeAllowed blocked |
| 69 | CCashDelegate | transfer / transferFrom | comptroller.transferAllowed blocked |
| 70 | CTokenDelegate | (all of the above) | Same reasons |

---

## Review Priority Summary

```
1-15   → Establish understanding of view/pure functions
16-35  → Verify single-write setter invariants (role protection, bounds)
36-44  → Understand KYC and oracle gates
45-52  → Understand token transfer invariants (KYC-gated ERC20)
53-58  → Mint request / redemption request invariants (epoch lifecycle)
59-61  → Full lifecycle closure (claimMint, completeRedemptions)
62-70  → Future: lending market invariants when wired
```
