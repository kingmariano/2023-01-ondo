# Reachability Analysis

## Overview

This document classifies every guarded branch in the 6 in-scope contracts by reachability,
identifies branches requiring shortcuts, and documents which shortcuts were created.

---

## 3a: Guarded Branch Classification

### CashManager.sol

| Function | Guard / Branch | Classification | Action |
|----------|---------------|----------------|--------|
| requestMint | `whenNotPaused` | DIRECT | Standard handler `cashManager_requestMint` works when not paused |
| requestMint | `checkKYC(msg.sender)` | DIRECT | Actor is pre-KYC'd in Setup; standard handler works |
| requestMint | `collateralAmountIn < minimumDepositAmount` revert branch | DIRECT | Fuzzer can hit by varying input; standard handler |
| requestMint | `_checkAndUpdateMintLimit` overflow branch | DIRECT | Fuzzer can exceed limit; standard handler |
| claimMint | `epochToExchangeRate[epochToClaim] == 0` revert | MULTI-STEP | Requires: (1) requestMint in epoch N, (2) setMintExchangeRate for epoch N, (3) warp to epoch N+1, (4) claimMint. Needs shortcut. |
| claimMint | `collateralDeposited == 0` revert | DIRECT | Standard handler with zero-epoch param hits this |
| setMintExchangeRate | `epochToSet >= currentEpoch` revert | MULTI-STEP | Requires epoch advance (warp). Needs shortcut. |
| setMintExchangeRate | `rateDifference > maxDifferenceThisEpoch` (pause branch) | MULTI-STEP | Requires prior epoch + large rate delta. Needs shortcut. |
| overrideExchangeRate | `epochToSet >= currentEpoch` revert | MULTI-STEP | Requires warp to advance epoch first |
| requestRedemption | `amountCashToRedeem < minimumRedeemAmount` | DIRECT | Standard handler |
| requestRedemption | `_checkAndUpdateRedeemLimit` | DIRECT | Standard handler |
| requestRedemption | `cash.burnFrom` | MULTI-STEP | Requires actor to hold CASH first (claim mint first). Needs shortcut. |
| completeRedemptions | `epochToService >= currentEpoch` | MULTI-STEP | Requires warp + past redemption. Admin function. |
| completeRedemptions | `_processRefund` (cash.mint for refundees) | MULTI-STEP | Requires prior requestRedemption. |
| transitionEpoch | `epochDifference > 0` | MULTI-STEP | Requires warp. Shortcut: warp + call. |
| multiexcall | `whenPaused` gate | MULTI-STEP | Requires pause first. Needs shortcut. |
| setPendingMintBalance | `epoch > currentEpoch` | DIRECT | Admin handler; bound epoch to current |
| setPendingRedemptionBalance | `balance < previousBalance` (totalBurned decrement) | MULTI-STEP | Requires prior requestRedemption |

### KYCRegistry.sol

| Function | Guard / Branch | Classification | Action |
|----------|---------------|----------------|--------|
| addKYCAddressViaSignature | `v == 27 || v == 28` | DIRECT | Fuzzer can supply valid v |
| addKYCAddressViaSignature | EIP-712 ECDSA valid sig | INDIRECT | Requires private-key signer to produce valid EIP-712 sig. Needs shortcut using pre-stored private key. |
| addKYCAddresses | `onlyRole(kycGroupRoles[group])` | DIRECT | Admin handler covers this |
| removeKYCAddresses | `onlyRole(kycGroupRoles[group])` | DIRECT | Admin handler covers this |

### OndoPriceOracleV2.sol

| Function | Guard / Branch | Classification | Action |
|----------|---------------|----------------|--------|
| getUnderlyingPrice | OracleType.MANUAL branch | DIRECT | Set via setPrice in Setup |
| getUnderlyingPrice | OracleType.COMPOUND branch | MOCK-DEPENDENT | cTokenOracle default is mainnet address; COMPOUND path unreachable without wiring |
| getUnderlyingPrice | OracleType.CHAINLINK branch | MOCK-DEPENDENT | Requires fToken CHAINLINK config + mock aggregator; chainlinkOracle mock deployed in Setup |
| getUnderlyingPrice | price cap applied branch (`fTokenToUnderlyingPriceCap[fToken] > 0`) | MULTI-STEP | Requires setPriceCap first, then getUnderlyingPrice. Needs shortcut. |
| setFTokenToCToken | `fTokenToOracleType[fToken] == OracleType.COMPOUND` | INDIRECT | Requires prior setFTokenToOracleType(COMPOUND) + wired underlying |
| setFTokenToChainlinkOracle | `fTokenToOracleType[fToken] == OracleType.CHAINLINK` | INDIRECT | Requires prior setFTokenToOracleType(CHAINLINK) |
| getChainlinkOraclePrice | staleness check | MOCK-DEPENDENT | MockAggregatorV3 returns block.timestamp; always passes |
| getChainlinkOraclePrice | `answer < 0` revert | MOCK-DEPENDENT | Mock returns positive; to test negative path, need setAnswer(-1) |

### CashKYCSenderReceiver.sol

| Function | Guard / Branch | Classification | Action |
|----------|---------------|----------------|--------|
| _beforeTokenTransfer | `_getKYCStatus(msg.sender)` fail | DIRECT | Remove caller from KYC; standard handler with non-KYC'd actor |
| _beforeTokenTransfer | `_getKYCStatus(from)` fail (non-mint) | DIRECT | Remove from from KYC |
| _beforeTokenTransfer | `_getKYCStatus(to)` fail (non-burn) | DIRECT | Remove to from KYC |
| transfer | KYC'd path success | DIRECT | Both parties KYC'd; standard handler works |
| transferFrom | Allowance check | DIRECT | Standard approve + transferFrom handler |
| mint | MINTER_ROLE gate | DIRECT | Admin handler `cashKYCSenderReceiver_mint` works |
| burn | Self-burn, KYC'd sender | DIRECT | Standard handler |
| burnFrom | Allowance + KYC | DIRECT | Standard handler with setup approval |

### CCashDelegate.sol (Bare — BLOCKED)

| Function | Guard / Branch | Classification | Action |
|----------|---------------|----------------|--------|
| accrueInterest | `interestRateModel == address(0)` | UNREACHABLE | IRM not set; all paths through here REVERT |
| mint | `accrueInterest` call + comptroller | UNREACHABLE | Blocked by IRM=0 and admin=0 |
| redeem / redeemUnderlying | Same | UNREACHABLE | Blocked |
| borrow | Same | UNREACHABLE | Blocked |
| repayBorrow | Same | UNREACHABLE | Blocked |
| liquidateBorrow | Same | UNREACHABLE | Blocked |
| seize | `comptroller == address(0)` | UNREACHABLE | Blocked |
| transfer / transferFrom | `comptroller.transferAllowed` | UNREACHABLE | Blocked |
| approve | No external deps | DIRECT | Standard handler `cCashDelegate_approve` works |
| _becomeImplementation | `admin == address(0)` | UNREACHABLE | admin is address(0) on bare delegate |
| _resignImplementation | Same | UNREACHABLE | |
| _acceptAdmin | `pendingAdmin` check | INDIRECT | Requires setPendingAdmin first (which requires admin != address(0)) |
| _setReserveFactor | `admin == address(0)` | UNREACHABLE | |
| _reduceReserves | `admin == address(0)` | UNREACHABLE | |

### CTokenDelegate.sol (Bare — BLOCKED)

Same as CCashDelegate. All state-changing functions UNREACHABLE due to admin=address(0) and IRM=address(0).

- approve: DIRECT (no comptroller needed)
- All other lending functions: UNREACHABLE

---

## 3b: Branches Requiring Shortcuts

### Shortcut 1: Warp + Transition Epoch
**Need:** Many functions require `currentEpoch > 0` (past epoch). Setup starts at epoch 0.
Requires `vm.warp(block.timestamp + epochDuration)` then `transitionEpoch()`.

### Shortcut 2: Full Mint Cycle (requestMint → setMintExchangeRate → claimMint)
**Need:** claimMint requires both (a) a past mint request and (b) an exchange rate for that epoch.
Standard handlers can't atomically advance the epoch between request and claim.

### Shortcut 3: Full Redemption Cycle (requestRedemption → completeRedemptions)
**Need:** completeRedemptions requires prior requestRedemption AND past epoch.

### Shortcut 4: multiexcall (pause first)
**Need:** multiexcall requires contract to be paused. Standard admin handler will always revert unless paused.

### Shortcut 5: Chainlink price path
**Need:** getUnderlyingPrice CHAINLINK branch requires fToken configured as CHAINLINK with oracle set.

### Shortcut 6: Price cap path (setPriceCap + getUnderlyingPrice)
**Need:** Price cap branch requires fToken to have a cap set before getUnderlyingPrice is called.

### Shortcut 7: KYC via Signature
**Need:** addKYCAddressViaSignature requires valid EIP-712 signature from key with kycGroupRoles[group] role.
The Setup has a pre-stored private key; shortcut uses vm.sign to produce valid signature.

---

## 3c: Existing Target Functions Review

After reading all target files:

**Already covered (standard handlers):**
- CashManager: requestMint, requestRedemption, claimMint, transitionEpoch, completeRedemptions (admin)
- KYCRegistry: addKYCAddressViaSignature, addKYCAddresses, removeKYCAddresses (admin)
- OndoPriceOracleV2: setPrice, setFTokenToOracleType, setPriceCap, setOracle, etc. (admin)
- CashKYCSenderReceiver: transfer, transferFrom, approve, mint, burn, burnFrom
- CCashDelegate/CTokenDelegate: approve, all lending (reverts documented)
- ManagersTargets: switchActor, asset_approve, asset_mint

**Missing shortcuts:**
- No warp-based shortcut for epoch advancement
- No full mint cycle shortcut (requestMint + exchange rate + claimMint atomically)
- No full redemption cycle shortcut
- No multiexcall shortcut (pauses, calls, unpauses)
- No Chainlink oracle path shortcut
- No price-cap verification shortcut
- No KYC-via-signature shortcut with pre-stored key

---

## 3d: Shortcut Target Functions Created

Shortcuts were added to `forge-tests/recon/targets/CashManagerTargets.sol` and
`forge-tests/recon/targets/OndoPriceOracleV2Targets.sol`.

### shortcut_warpAndTransitionEpoch
Warps time forward by epochDuration to advance the epoch counter.
Enables: setMintExchangeRate, overrideExchangeRate, completeRedemptions (past epoch requirement).

### shortcut_fullMintCycle
Atomically: requestMint (as actor) → warp epoch → setMintExchangeRate (as admin) → claimMint (as actor).
Enables: claimMint success path; generates CASH tokens for actor.

### shortcut_fullRedemptionCycle
Atomically: requestRedemption (as actor, requires CASH balance) → warp epoch → completeRedemptions (as admin).
Enables: completeRedemptions success path.

### shortcut_mintThenRequestRedemption
Atomically mints CASH to actor then calls requestRedemption.
Enables: requestRedemption success path when actor has no CASH.

### shortcut_pauseAndMultiexcall
Pauses contract, calls multiexcall with provided data, then unpauses.
Enables: multiexcall code path (requires whenPaused).

### shortcut_chainlinkOraclePath
Sets fToken oracle type to CHAINLINK, sets chainlink oracle, then calls getUnderlyingPrice.
Enables: CHAINLINK oracle branch in getUnderlyingPrice.

### shortcut_priceCapPath
Sets price cap and verifies getUnderlyingPrice returns min(price, cap).
Enables: price cap branch in getUnderlyingPrice.

### shortcut_kycViaSignature
Uses pre-stored private key (userPrivateKey from Setup) to produce valid EIP-712 signature,
then calls addKYCAddressViaSignature.
Enables: signature-based KYC path.

---

## 3e: Setup Changes Needed (ANALYSIS ONLY)

The following require Setup.sol changes to reach (NOT implemented — analysis only):

1. **CCashDelegate / CTokenDelegate lending functions**: All require deploying behind a
   cErc20ModifiedDelegator proxy (to set admin), deploying a Comptroller and InterestRateModel,
   and calling initialize(). This is a full Compound market wiring — deferred to coverage phase.

2. **OndoPriceOracleV2 COMPOUND oracle path**: Requires pointing cTokenOracle at a mock/real
   CTokenOracle contract and configuring an fToken-to-cToken mapping.

3. **cToken KYC/admin admin functions**: All require admin != address(0) which requires proxy
   deployment.

---

## 3f: ALWAYS_REVERTS Functions (Confirmed)

The following standard target functions always revert based on the setup and are documented in
`magic/reverting-handlers.json`:

- cCashDelegate_accrueInterest, cCashDelegate_exchangeRateCurrent, cCashDelegate_totalBorrowsCurrent
- cCashDelegate_balanceOfUnderlying, cCashDelegate_borrowBalanceCurrent
- cCashDelegate_mint, cCashDelegate_redeem, cCashDelegate_redeemUnderlying
- cCashDelegate_borrow, cCashDelegate_repayBorrow, cCashDelegate_repayBorrowBehalf
- cCashDelegate_seize, cCashDelegate_transfer, cCashDelegate_transferFrom
- cCashDelegate_setKYCRegistry, cCashDelegate_setKYCRequirementGroup
- (All cTokenDelegate equivalents)
- ondoPriceOracleV2_setFTokenToCToken, ondoPriceOracleV2_setFTokenToChainlinkOracle
