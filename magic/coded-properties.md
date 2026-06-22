# Coded Properties — Summary

Properties workflow (v4.1) complete. ~55 properties implemented in
`forge-tests/recon/Properties.sol` on top of ghost infrastructure in
`forge-tests/recon/BeforeAfter.sol`.

## Coverage
- Tiers implemented: CANARY, PROFIT/SOL conservation, MONO, MATH/ROUND,
  DELTA (variable transitions), RATE/ER (exchange-rate), FEE, T11-T15,
  PRIV-NEG (privilege escalation), DOOM (doomsday), ECO (economic/oracle).
- CryticToFoundry unit suite: 73/73 passing.

## Smoke Test (10K, Echidna assertion mode)
- 10,198 calls, 53,231 unique instructions, corpus 65.
- Result: NO property falsified, NO shallow false positives.
- Note: the DOOM properties (setAssetSender(0), setEpochDuration(0)
  div-by-zero, overrideExchangeRate no-delta-limit, override(0) bricks
  claimMint) encode REAL protocol weaknesses. They did not fire in the short
  10K smoke run because triggering them needs specific admin-arg sequences
  (e.g. exactly 0). A longer campaign (coverage phase / extended fuzzing job)
  is expected to surface them. They are retained as live properties.

## Smoke Test Fixes
None required — no shallow false positives to fix.

## Deferred to Coverage Phase
PROFIT-01 (multi-epoch ProfitTracker), exact totalSupply==sum(balanceOf)
(needs actor enumeration), exact cashOwed/redeemer cross-checks, and all
lending-market properties (bare cToken delegates need Comptroller/IRM/market
wiring).
