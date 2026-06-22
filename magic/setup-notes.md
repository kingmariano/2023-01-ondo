# Recon Setup Notes — Ondo (Phase 0b)

Status: `forge build` succeeds (warnings only). `forge test --match-contract CryticToFoundry` passes — `setUp()` does not revert.

## What was deployed and wired (in `forge-tests/recon/Setup.sol::setup()`)

1. **Time/block init** — `vm.warp(1_700_000_000)` (non-zero timestamp for epoch modulo & Chainlink freshness) and `vm.roll(1_000)` (non-zero block for cToken accrual).
2. **MockSanctionsList** — deployed and passed to `KYCRegistry`; its runtime is also `vm.etch`'d onto the hardcoded constant `0x40C57923924B5c5c5455c48D93317139ADDaC8fb` used by the cToken/cCash interfaces. `isSanctioned` always returns false.
3. **KYCRegistry** — `constructor(admin=address(this), sanctionsList)`. `assignRoletoKYCGroup(KYC_GROUP=1, REGISTRY_ADMIN)` so `address(this)` (holds REGISTRY_ADMIN) can `addKYCAddresses` for that group.
4. **OndoPriceOracleV2** — owner = deployer (`address(this)`). Set to MANUAL oracle type + `setPrice(1e18)` for both delegate addresses (treated as fTokens). A `MockAggregatorV3` is also deployed for any future CHAINLINK-path coverage.
5. **CashKYCSenderReceiver (CASH token)** — implementation deployed, wrapped in `ERC1967Proxy`, `initialize("Ondo CASH","CASH", kycRegistry, KYC_GROUP)` called through the proxy. The proxy is treated as the live token. Deployed BEFORE CashManager (constructor reads `cash.decimals()` = 18).
6. **CashManager** — full 12-arg constructor. collateral = 6-dec USDC MockERC20; cash = CASH proxy; admin/pauser/recipients/sender = `address(this)`; mint/redeem limits = `type(uint128).max`; epochDuration = `1 days`; group = 1. Granted `MINTER_ROLE` on the CASH token afterward.
7. **CTokenDelegate / CCashDelegate** — deployed bare (empty constructors). See gap below.
8. **Actors** — `address(this)` (actor 0) plus the keyed actor `0x537C...6802` (private key set per spec). Both KYC'd in group 1; CashManager and CCashDelegate also KYC'd so they can custody KYC-gated CASH.
9. **Asset finalization** — `_finalizeAssetDeployment(_getActors(), [cashManager], type(uint88).max)` mints collateral + DAI-like underlying to all actors and approves CashManager.

## Tokens (via AssetManager)
- `collateralToken` = `_newAsset(6)` — USDC-like, 6 decimals (decimalsMultiplier = 1e12).
- `underlyingToken` = `_newAsset(18)` — DAI-like generic cToken underlying.
- CASH = CashKYCSenderReceiver proxy, 18 decimals (added as the `_cash` consumer).

## Helpers added
- `_etchSanctionsList()` — deploy + etch the sanctions mock onto the constant.
- `_deployCashTokenBehindProxy()` — impl + ERC1967Proxy + initialize.
- `_kycActor(address)` — addKYCAddresses for one address in KYC_GROUP.

## Gaps / not fully wired (documented per spec)
- **Lending markets are partial.** `CTokenDelegate`/`CCashDelegate` are deployed as bare implementations. Their `initialize` requires `msg.sender == admin` while the bare delegate's `admin` is `address(0)`, and full operation needs a Comptroller + InterestRateModel + delegator proxy. This heavier wiring was deliberately deferred (the spec allows a minimal compiling deployment). Consequence: most cToken/cCash state-changing handlers will revert until a future COVERAGE phase stands up real markets (e.g. via `deploy_cToken_market` / `deploy_cCash_market` helpers). The oracle is still pointed at both delegates in MANUAL mode so price reads succeed.
- **Signature KYC** — a keyed actor (`vm.addr(userPrivateKey)`) and the registry are set up, but no EIP-712 `_signKYCApproval` helper is wired into Setup; `addKYCAddressViaSignature` coverage would need that helper in TargetFunctions.
- **Oracle COMPOUND path** — not exercised; relies on the live mainnet `0x65c8...` address. MANUAL path is used instead.
- **Chainlink path** — `MockAggregatorV3` is deployed and ready but not attached to a delegate by default; MANUAL is used.

## Key assumptions
- Single KYC group constant `KYC_GROUP = 1` used consistently across registry approvals, the CASH token, and CashManager.
- `address(this)` is the global admin/owner/recipient/sender (standard Recon concentration of privilege).
- Mint/redeem limits set very high so they don't trivially block fuzzed mint/redeem.
