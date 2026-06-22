# Setup Wiring Analysis

## 5a: Constructor Parameter Analysis

### KYCRegistry
- **Constructor:** `constructor(address admin, address _sanctionsList)`
- `admin = address(this)` — harness holds DEFAULT_ADMIN_ROLE and REGISTRY_ADMIN
- `_sanctionsList = address(sanctionsList)` — MockSanctionsList deployed and passed
- STATUS: CORRECTLY_WIRED. Admin is address(this), sanctionsList is a live mock.

### OndoPriceOracleV2
- **Constructor:** (Ownable, no args) — owner = msg.sender = address(this)
- Post-deploy: setFTokenToOracleType(cTokenDelegate, MANUAL), setPrice(cTokenDelegate, 1e18)
- Post-deploy: setFTokenToOracleType(cCashDelegate, MANUAL), setPrice(cCashDelegate, 1e18)
- STATUS: CORRECTLY_WIRED for MANUAL path. COMPOUND path blocked (hardcoded 0x65c8... oracle).
  CHAINLINK path partially wired (MockAggregatorV3 deployed but not assigned to any fToken).

### CashKYCSenderReceiver (proxy)
- **Proxy deploy:** `ERC1967Proxy(address(impl), initData)`
- `initData = initialize("Ondo CASH", "CASH", address(kYCRegistry), KYC_GROUP)`
- impl constructed with `_disableInitializers()` — proxy pattern correctly used
- Post-deploy: `cashKYCSenderReceiver.grantRole(MINTER_ROLE, address(cashManager))`
- STATUS: CORRECTLY_WIRED. Proxy deployed, initialized through proxy, MINTER_ROLE granted.

### CashManager
- **Constructor args (12):**
  - `_collateral = collateralToken` — 6-decimal MockERC20 (USDC-like)
  - `_cash = address(cashKYCSenderReceiver)` — CASH proxy (18-decimal)
  - `managerAdmin = address(this)` — harness holds MANAGER_ADMIN
  - `pauser = address(this)` — harness holds PAUSER_ADMIN
  - `_assetRecipient = address(this)` — receives collateral on requestMint
  - `_assetSender = address(this)` — sends collateral on completeRedemptions
  - `_feeRecipient = address(this)` — receives fees
  - `_mintLimit = type(uint128).max` — large non-zero limit
  - `_redeemLimit = type(uint128).max` — large non-zero limit
  - `_epochDuration = 1 days` — valid non-zero epoch
  - `_kycRegistry = address(kYCRegistry)`
  - `_kycRequirementGroup = KYC_GROUP (1)`
- Post-deploy: `cashManager.grantRole(SETTER_ADMIN, address(this))`
- STATUS: CORRECTLY_WIRED. All 12 args non-zero, SETTER_ADMIN self-granted.

### CTokenDelegate (bare)
- **Constructor:** `constructor() {}` — no args
- admin = address(0) — NOT INITIALIZED
- interestRateModel = address(0) — NOT INITIALIZED
- comptroller = address(0) — NOT INITIALIZED
- STATUS: NEEDS_REAL_VALUE — bare delegate. Admin is address(0), no market initialized.
- All state-changing handlers ALWAYS_REVERT (documented in reverting-handlers.json).

### CCashDelegate (bare)
- Same as CTokenDelegate. Bare constructor, no initialization.
- STATUS: NEEDS_REAL_VALUE — bare delegate.

---

## 5b: Proxy Pattern Detection

### CashKYCSenderReceiver — ERC1967 Proxy
- Implementation: `CashKYCSenderReceiver` (constructor calls `_disableInitializers()`)
- Proxy: `ERC1967Proxy` wraps impl and calls `initialize()` through proxy
- Proxy address is treated as the live token
- Post-initialize: address(this) holds DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE on proxy
- MINTER_ROLE granted to cashManager

### CCashDelegate / CTokenDelegate — Compound Delegate Pattern
- These are bare delegate IMPLEMENTATIONS (not behind a proxy)
- In production: cErc20ModifiedDelegator sets admin = msg.sender and delegatecalls into delegate
- In harness: deployed bare with admin = address(0) — proxy deployment deferred to coverage phase

---

## 5c: Access Control Pattern Analysis

| Actor in Setup | Roles Held |
|----------------|-----------|
| address(this) | KYCRegistry: DEFAULT_ADMIN_ROLE, REGISTRY_ADMIN |
| address(this) | CashManager: DEFAULT_ADMIN_ROLE, MANAGER_ADMIN, PAUSER_ADMIN, SETTER_ADMIN |
| address(this) | CashKYCSenderReceiver: DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE |
| address(this) | OndoPriceOracleV2: owner |
| cashManager | CashKYCSenderReceiver: MINTER_ROLE |
| user | KYCRegistry: KYC'd in KYC_GROUP (not a role holder) |
| address(this) | KYCRegistry: KYC'd in KYC_GROUP |

**Role gaps identified:**
1. No KYC_CONFIGURER_ROLE pre-granted for CashKYCSenderReceiver. address(this) holds DEFAULT_ADMIN_ROLE which is admin of all roles so it can self-grant, but it's not pre-granted.
2. CCashDelegate/CTokenDelegate: admin = address(0). No actor can call admin functions.

---

## 5d: Funding Analysis

### Collateral token (6-decimal MockERC20)
- Funded via `_finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max)`
- Mints type(uint88).max collateral tokens to all actors (address(this) and user)
- All actors approve CashManager with type(uint88).max
- assetSender = address(this) — also funded
- STATUS: CORRECTLY_FUNDED for requestMint and completeRedemptions

### CASH token (CashKYCSenderReceiver)
- Not pre-funded — CASH is created via claimMint / admin mint
- address(this), user, cashManager, cCashDelegate are KYC'd so they can hold/receive CASH
- STATUS: CORRECTLY_WIRED (actors KYC'd, CashManager has MINTER_ROLE)

### Underlying token (18-decimal MockERC20)
- `underlyingToken = _newAsset(18)` — deployed but NOT assigned to any cToken
- Neither cCashDelegate nor cTokenDelegate has been initialized with an underlying
- STATUS: PARTIALLY_WIRED. Token exists but cToken markets not wired.

---

## 5e: Protocol Configuration

| Configuration | Value | Impact |
|---------------|-------|--------|
| KYC_GROUP | 1 | All actors KYC'd in group 1; must match registry group |
| epochDuration | 1 days (86400 sec) | Epochs advance every day of warped time |
| minimumDepositAmount | 10_000 (default) | requestMint reverts for small amounts |
| minimumRedeemAmount | 0 (default) | requestRedemption allows zero minimum |
| mintLimit | type(uint128).max | Effectively unlimited |
| redeemLimit | type(uint128).max | Effectively unlimited |
| lastSetMintExchangeRate | 1e6 (default) | Starting exchange rate |
| exchangeRateDeltaLimit | 100 bps (default) | setMintExchangeRate pauses if rate moves more than 1% |
| mintFee | 0 (default) | No mint fee |
| decimalsMultiplier | 1e12 | cash(18dec) - collateral(6dec) = 1e12 |
| maxChainlinkOracleTimeDelay | 90000 sec (default) | 25 hours freshness window |

---

## 5f: Wiring Analysis Summary

### Correctly Wired (OPERATIONAL)
- KYCRegistry: admin, sanctionsList, KYC_GROUP assignment, actor KYC
- CashKYCSenderReceiver: proxy deployed, initialized, MINTER_ROLE granted to CashManager
- CashManager: all 12 constructor args non-zero, SETTER_ADMIN self-granted
- OndoPriceOracleV2: MANUAL path wired for both delegates
- MockSanctionsList: etched onto hardcoded constant 0x40C5...
- MockAggregatorV3: deployed (not assigned to any fToken yet)
- Actors: address(this) and user are KYC'd; cashManager and cCashDelegate KYC'd
- Collateral: actors funded and approved

### Partially Wired (LIMITED COVERAGE)
- OndoPriceOracleV2 CHAINLINK path: mock deployed but no fToken configured for CHAINLINK
- Underlying token: deployed as MockERC20 but not assigned to cToken market

### NOT Wired (DEFERRED — Requires Setup Changes)
- CCashDelegate / CTokenDelegate: bare delegates with admin=address(0), IRM=address(0)
  - Requires: cErc20ModifiedDelegator proxy, Comptroller, InterestRateModel, underlying ERC20
  - Impact: ALL lending state-changing functions ALWAYS_REVERT

---

## 5g: ANALYSIS ONLY — Setup.sol was not modified

---

## 5h: Address Aliasing Detection

1. `assetRecipient = assetSender = feeRecipient = address(this)` — circular flows possible.
   On requestMint, collateral is transferred TO address(this) (assetRecipient + feeRecipient).
   On completeRedemptions, collateral is pulled FROM address(this) (assetSender). Since
   address(this) is both sender and recipient, circular flows are possible.
2. The KYCRegistry grants REGISTRY_ADMIN to address(this) which also holds the kycGroupRoles
   assignment — so address(this) can unilaterally add/remove any address from KYC.
3. user is at 0x537C8f3d3E18dF5517a58B3fB9D9143697996802 (derived from userPrivateKey).
   Distinct from address(this). No aliasing.
4. cCashDelegate KYC'd in Setup so it can hold CASH — important for future cCASH market wiring.

---

## Step 9: Liveness Checks and Always-Revert Flags

### LIVENESS_CHECK statements

```
LIVENESS_CHECK: require(address(cashManager) != address(0), "SETUP: cashManager not deployed");
LIVENESS_CHECK: require(address(cashKYCSenderReceiver) != address(0), "SETUP: cashKYCSenderReceiver not deployed");
LIVENESS_CHECK: require(address(kYCRegistry) != address(0), "SETUP: kYCRegistry not deployed");
LIVENESS_CHECK: require(address(ondoPriceOracleV2) != address(0), "SETUP: ondoPriceOracleV2 not deployed");
LIVENESS_CHECK: require(address(collateralToken) != address(0), "SETUP: collateralToken not deployed");
LIVENESS_CHECK: require(address(cTokenDelegate) != address(0), "SETUP: cTokenDelegate not deployed");
LIVENESS_CHECK: require(address(cCashDelegate) != address(0), "SETUP: cCashDelegate not deployed");
```

### ALWAYS_REVERTS — Confirmed Handler List

```
ALWAYS_REVERTS: cCashDelegate_accrueInterest — interestRateModel == address(0)
ALWAYS_REVERTS: cCashDelegate_exchangeRateCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cCashDelegate_totalBorrowsCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cCashDelegate_balanceOfUnderlying — calls exchangeRateCurrent, IRM=0
ALWAYS_REVERTS: cCashDelegate_borrowBalanceCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cCashDelegate_mint — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_redeem — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_redeemUnderlying — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_borrow — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_repayBorrow — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_repayBorrowBehalf — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cCashDelegate_seize — comptroller.seizeAllowed (comptroller=0)
ALWAYS_REVERTS: cCashDelegate_transfer — comptroller.transferAllowed (comptroller=0)
ALWAYS_REVERTS: cCashDelegate_transferFrom — comptroller.transferAllowed (comptroller=0)
ALWAYS_REVERTS: cCashDelegate_setKYCRegistry — admin == address(0)
ALWAYS_REVERTS: cCashDelegate_setKYCRequirementGroup — admin == address(0)
ALWAYS_REVERTS: cCashDelegate__becomeImplementation — admin == address(0)
ALWAYS_REVERTS: cCashDelegate__resignImplementation — admin == address(0)
ALWAYS_REVERTS: cCashDelegate__setReserveFactor — admin == address(0)
ALWAYS_REVERTS: cCashDelegate__reduceReserves — admin == address(0)
ALWAYS_REVERTS: cCashDelegate__addReserves — accrueInterest (IRM=0) + underlying=0
ALWAYS_REVERTS: cTokenDelegate_accrueInterest — interestRateModel == address(0)
ALWAYS_REVERTS: cTokenDelegate_exchangeRateCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cTokenDelegate_totalBorrowsCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cTokenDelegate_balanceOfUnderlying — calls exchangeRateCurrent, IRM=0
ALWAYS_REVERTS: cTokenDelegate_borrowBalanceCurrent — calls accrueInterest, IRM=0
ALWAYS_REVERTS: cTokenDelegate_mint — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_redeem — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_redeemUnderlying — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_borrow — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_repayBorrow — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_repayBorrowBehalf — accrueInterest (IRM=0) + comptroller=0
ALWAYS_REVERTS: cTokenDelegate_seize — comptroller.seizeAllowed (comptroller=0)
ALWAYS_REVERTS: cTokenDelegate_transfer — comptroller.transferAllowed (comptroller=0)
ALWAYS_REVERTS: cTokenDelegate_transferFrom — comptroller.transferAllowed (comptroller=0)
ALWAYS_REVERTS: cTokenDelegate_setKYCRegistry — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate_setKYCRequirementGroup — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate__becomeImplementation — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate__resignImplementation — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate__setReserveFactor — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate__reduceReserves — admin == address(0)
ALWAYS_REVERTS: cTokenDelegate__addReserves — accrueInterest (IRM=0) + underlying=0
ALWAYS_REVERTS: ondoPriceOracleV2_setFTokenToCToken — requires OracleType.COMPOUND + wired underlying
ALWAYS_REVERTS: ondoPriceOracleV2_setFTokenToChainlinkOracle — requires OracleType.CHAINLINK + wired underlying
ALWAYS_REVERTS: cashManager_multiexcall — requires whenPaused (use shortcut_pauseAndMultiexcall)
```

### PARTIAL_REVERTS — Conditional Handlers

```
PARTIAL_REVERTS: cashManager_claimMint — reverts if no prior requestMint + exchange rate set
                 (use shortcut_fullMintCycle for success path)
PARTIAL_REVERTS: cashManager_requestRedemption — reverts if actor has no CASH balance
                 (use shortcut_mintCashThenRequestRedemption for success path)
PARTIAL_REVERTS: cashManager_setMintExchangeRate — reverts if currentEpoch == 0
                 (use shortcut_warpAndTransitionEpoch first)
PARTIAL_REVERTS: cashManager_completeRedemptions — reverts if epoch not past
                 (use shortcut_warpAndTransitionEpoch first)
PARTIAL_REVERTS: kYCRegistry_addKYCAddressViaSignature — reverts on invalid signature
                 (use shortcut_kycViaSignature for success path)
```
