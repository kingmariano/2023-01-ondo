# Coverage Phase 5 — Implemented Solutions

(Summary reconstructed after the implementing run hit the session limit; suite
verified: `forge build` exit 0, CryticToFoundry 73/73 passing.)

## Group C — Trivial admin/view branches (IMPLEMENTED)
- `ondoPriceOracleV2_owner()` handler — covers `Ownable.owner`.
- `ondoPriceOracleV2_transferOwnership_clamped()` (asAdmin, clamps `to`, transfers
  back) — covers `Ownable.transferOwnership` + `onlyOwner`.
- `cashKYCSenderReceiver_setKYCRegistry_clamped()` (asAdmin) — covers
  `CashKYCSenderReceiver.setKYCRegistry` (configurer role granted in Setup).

## Group B — Oracle alternate paths (IMPLEMENTED)
- Setup.sol wires OndoPriceOracleV2 COMPOUND + CHAINLINK paths using new mocks:
  MockComptroller, MockInterestRateModel, MockFToken, MockCTokenOracle,
  MockERC20Decimals.
- Handlers added: `ondoPriceOracleV2_getChainlinkOraclePrice_clamped`,
  `ondoPriceOracleV2_setFTokenToCToken_compound_clamped`,
  `ondoPriceOracleV2_setFTokenToChainlinkOracle_chainlink_clamped` — exercise the
  COMPOUND and CHAINLINK branches of `getUnderlyingPrice` / `getChainlinkOraclePrice`.

## Group A — Lending market wiring for the real cToken delegates (DEFERRED)
- The real `CCashDelegate`/`CTokenDelegate` state-changing functions remain
  unreachable: they are deployed BARE (admin==address(0), no CErc20DelegatorKYC
  delegator, no live Comptroller/IRM on the delegate itself). The delegate
  revert-tests still pass (they assert the revert), confirming the bare state.
- Remaining steps to close Group A (future work): deploy CErc20DelegatorKYC
  delegators pointing at the delegate impls, initialize with admin=address(this)
  + a real Comptroller + JumpRateModelV2 + underlying ERC20, _supportMarket, set
  price, fund + enterMarkets, then retarget the cToken handlers at the delegator
  proxies. This is the deep Compound wiring deferred since setup phase 0b.
