# Contracts Dependency List

## CashManager.sol

### requestMint
Storage Slots Read:
- minimumDepositAmount
- mintFee (via _getMintFees)
- BPS_DENOMINATOR
- mintLimit
- currentMintAmount
- currentEpoch
- currentEpochStartTimestamp
- epochDuration
- collateral (immutable)
- feeRecipient
- assetRecipient
- decimalsMultiplier (immutable)

Storage Slots Written:
- mintRequestsPerEpoch[currentEpoch][msg.sender]
- currentMintAmount (via _checkAndUpdateMintLimit)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)
- _getKYCStatus(msg.sender) (via checkKYC modifier)
- _getMintFees(collateralAmountIn)
- _checkAndUpdateMintLimit(depositValueAfterFees)
- collateral.safeTransferFrom(msg.sender, feeRecipient, fees)
- collateral.safeTransferFrom(msg.sender, assetRecipient, depositValueAfterFees)
- KYCRegistry.getKYCStatus (via _getKYCStatus)
- ISanctionsList.isSanctioned (via KYCRegistry.getKYCStatus)

Is called by:
- (external users)

---

### claimMint
Storage Slots Read:
- mintRequestsPerEpoch[epochToClaim][user]
- epochToExchangeRate[epochToClaim]
- currentEpoch
- currentEpochStartTimestamp
- epochDuration
- decimalsMultiplier (immutable, via _getMintAmountForEpoch)

Storage Slots Written:
- mintRequestsPerEpoch[epochToClaim][user] (set to 0)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)
- currentMintAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)
- _getKYCStatus(user) (via checkKYC modifier)
- _getMintAmountForEpoch(collateralDeposited, epochToClaim)
- cash.mint(user, cashOwed)
- KYCRegistry.getKYCStatus
- ISanctionsList.isSanctioned

Is called by:
- (external callers, any address)

---

### requestRedemption
Storage Slots Read:
- minimumRedeemAmount
- redeemLimit
- currentRedeemAmount
- currentEpoch
- currentEpochStartTimestamp
- epochDuration

Storage Slots Written:
- redemptionInfoPerEpoch[currentEpoch].addressToBurnAmt[msg.sender]
- redemptionInfoPerEpoch[currentEpoch].totalBurned
- currentRedeemAmount (via _checkAndUpdateRedeemLimit)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)
- _getKYCStatus(msg.sender) (via checkKYC modifier)
- _checkAndUpdateRedeemLimit(amountCashToRedeem)
- cash.burnFrom(msg.sender, amountCashToRedeem)
- KYCRegistry.getKYCStatus
- ISanctionsList.isSanctioned

Is called by:
- (external users)

---

### completeRedemptions
Storage Slots Read:
- currentEpoch
- redemptionInfoPerEpoch[epochToService].totalBurned
- redemptionInfoPerEpoch[epochToService].addressToBurnAmt[redeemer/refundee]
- assetSender
- feeRecipient
- collateral (immutable)

Storage Slots Written:
- redemptionInfoPerEpoch[epochToService].addressToBurnAmt[redeemer/refundee] (set to 0)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)
- _checkAddressesKYC(redeemers)
- _checkAddressesKYC(refundees)
- _processRefund(refundees, epochToService) -> cash.mint
- _processRedemption(redeemers, amountToDist, quantityBurned, epochToService) -> collateral.safeTransferFrom
- collateral.safeTransferFrom(assetSender, feeRecipient, fees)
- KYCRegistry.getKYCStatus (via _checkAddressesKYC)
- ISanctionsList.isSanctioned

Is called by:
- (MANAGER_ADMIN role holder only)

---

### setMintExchangeRate
Storage Slots Read:
- currentEpoch
- epochToExchangeRate[epochToSet]
- lastSetMintExchangeRate
- exchangeRateDeltaLimit
- BPS_DENOMINATOR

Storage Slots Written:
- epochToExchangeRate[epochToSet]
- lastSetMintExchangeRate (conditionally)
- paused (via _pause() if delta check fails)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)
- _pause() (conditionally)

Is called by:
- (SETTER_ADMIN role holder)

---

### overrideExchangeRate
Storage Slots Read:
- currentEpoch
- epochToExchangeRate[epochToSet]

Storage Slots Written:
- epochToExchangeRate[epochToSet]
- lastSetMintExchangeRate (if _lastSetMintExchangeRate != 0)
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)

Is called by:
- (MANAGER_ADMIN role holder)

---

### transitionEpoch
Storage Slots Read:
- currentEpochStartTimestamp
- epochDuration

Storage Slots Written:
- currentRedeemAmount
- currentMintAmount
- currentEpoch
- currentEpochStartTimestamp

Calls:
- (none external)

Is called by:
- requestMint (via updateEpoch)
- claimMint (via updateEpoch)
- requestRedemption (via updateEpoch)
- completeRedemptions (via updateEpoch)
- setMintExchangeRate (via updateEpoch)
- overrideExchangeRate (via updateEpoch)
- setPendingMintBalance (via updateEpoch)
- setPendingRedemptionBalance (via updateEpoch)
- (external, public)

---

### setPendingMintBalance
Storage Slots Read:
- mintRequestsPerEpoch[epoch][user]
- currentEpoch

Storage Slots Written:
- mintRequestsPerEpoch[epoch][user]
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)

Is called by:
- (MANAGER_ADMIN role holder)

---

### setPendingRedemptionBalance
Storage Slots Read:
- redemptionInfoPerEpoch[epoch].addressToBurnAmt[user]
- currentEpoch

Storage Slots Written:
- redemptionInfoPerEpoch[epoch].addressToBurnAmt[user]
- redemptionInfoPerEpoch[epoch].totalBurned
- currentEpoch (via transitionEpoch)
- currentEpochStartTimestamp (via transitionEpoch)
- currentMintAmount (via transitionEpoch)
- currentRedeemAmount (via transitionEpoch)

Calls:
- transitionEpoch() (via updateEpoch modifier)

Is called by:
- (MANAGER_ADMIN role holder)

---

### multiexcall
Storage Slots Read:
- paused

Storage Slots Written:
- (arbitrary, depends on calls)

Calls:
- (arbitrary external calls to exCallData[i].target)

Is called by:
- (MANAGER_ADMIN when paused)

---

### Admin/setter functions (setMintFee, setMinimumDepositAmount, setFeeRecipient, setAssetRecipient, setAssetSender, setRedeemMinimum, setMintLimit, setRedeemLimit, setEpochDuration, setMintExchangeRateDeltaLimit, setKYCRegistry, setKYCRequirementGroup, pause, unpause)
Storage Slots Read:
- Respective state variable (current value for event logging)

Storage Slots Written:
- mintFee / minimumDepositAmount / feeRecipient / assetRecipient / assetSender / minimumRedeemAmount / mintLimit / redeemLimit / epochDuration / exchangeRateDeltaLimit / kycRegistry / kycRequirementGroup / paused

Calls:
- (none external; _pause/_unpause internally)

Is called by:
- (MANAGER_ADMIN or PAUSER_ADMIN role holder)

---

## KYCRegistry.sol

### addKYCAddresses
Storage Slots Read:
- kycGroupRoles[kycRequirementGroup]
- roles (AccessControl)

Storage Slots Written:
- kycState[kycRequirementGroup][addresses[i]] = true

Calls:
- onlyRole(kycGroupRoles[kycRequirementGroup]) (AccessControl check)

Is called by:
- (role holder for kycGroupRoles[kycRequirementGroup])
- CashManager (indirectly via admin)

---

### removeKYCAddresses
Storage Slots Read:
- kycGroupRoles[kycRequirementGroup]
- roles (AccessControl)

Storage Slots Written:
- kycState[kycRequirementGroup][addresses[i]] = false

Calls:
- onlyRole(kycGroupRoles[kycRequirementGroup]) (AccessControl check)

Is called by:
- (role holder for kycGroupRoles[kycRequirementGroup])

---

### addKYCAddressViaSignature
Storage Slots Read:
- kycState[kycRequirementGroup][user]
- kycGroupRoles[kycRequirementGroup]
- _APPROVAL_TYPEHASH
- _domainSeparatorV4 (EIP712)

Storage Slots Written:
- kycState[kycRequirementGroup][user] = true

Calls:
- ECDSA.recover(expectedMessage, v, r, s)
- _checkRole(kycGroupRoles[kycRequirementGroup], signer)
- _hashTypedDataV4(structHash) (EIP712)

Is called by:
- (any external caller with valid signature)

---

### getKYCStatus
Storage Slots Read:
- kycState[kycRequirementGroup][account]

Storage Slots Written:
- (none)

Calls:
- sanctionsList.isSanctioned(account)

Is called by:
- CashManager._checkKYC
- CashManager._checkAddressesKYC
- CashKYCSenderReceiver._beforeTokenTransfer
- CTokenCash.mintFresh / redeemFresh / borrowFresh / repayBorrowFresh / seizeInternal / transferTokens
- CTokenModified.mintFresh / redeemFresh / borrowFresh / repayBorrowFresh

---

### assignRoletoKYCGroup
Storage Slots Read:
- (AccessControl roles)

Storage Slots Written:
- kycGroupRoles[kycRequirementGroup] = role

Calls:
- onlyRole(REGISTRY_ADMIN) (AccessControl check)

Is called by:
- (REGISTRY_ADMIN role holder)

---

## OndoPriceOracleV2.sol

### getUnderlyingPrice
Storage Slots Read:
- fTokenToOracleType[fToken]
- fTokenToUnderlyingPrice[fToken] (MANUAL path)
- fTokenToCToken[fToken] (COMPOUND path)
- fTokenToChainlinkOracle[fToken] (CHAINLINK path)
- fTokenToUnderlyingPriceCap[fToken]
- maxChainlinkOracleTimeDelay (CHAINLINK path)

Storage Slots Written:
- (none)

Calls:
- cTokenOracle.getUnderlyingPrice(cTokenAddress) (COMPOUND path)
- getChainlinkOraclePrice(fToken) (CHAINLINK path)
- AggregatorV3Interface.latestRoundData() (CHAINLINK path)

Is called by:
- (Comptroller during market operations; external callers for price reads)

---

### setPrice
Storage Slots Read:
- fTokenToOracleType[fToken]
- fTokenToUnderlyingPrice[fToken]

Storage Slots Written:
- fTokenToUnderlyingPrice[fToken]

Calls:
- onlyOwner check

Is called by:
- (owner / harness)

---

### setFTokenToOracleType
Storage Slots Read:
- (Ownable owner)

Storage Slots Written:
- fTokenToOracleType[fToken]

Calls:
- onlyOwner check

Is called by:
- (owner)

---

### setPriceCap
Storage Slots Read:
- fTokenToUnderlyingPriceCap[fToken]

Storage Slots Written:
- fTokenToUnderlyingPriceCap[fToken]

Calls:
- onlyOwner check

Is called by:
- (owner)

---

### setFTokenToCToken
Storage Slots Read:
- fTokenToOracleType[fToken]

Storage Slots Written:
- fTokenToCToken[fToken]

Calls:
- onlyOwner check
- CTokenLike(fToken).underlying()
- CTokenLike(cToken).underlying()

Is called by:
- (owner; requires OracleType.COMPOUND)

---

### setFTokenToChainlinkOracle
Storage Slots Read:
- fTokenToOracleType[fToken]
- fTokenToChainlinkOracle[fToken].oracle

Storage Slots Written:
- fTokenToChainlinkOracle[fToken].oracle
- fTokenToChainlinkOracle[fToken].scaleFactor

Calls:
- onlyOwner check
- CTokenLike(fToken).underlying()
- IERC20Like(underlying).decimals()
- AggregatorV3Interface(chainlinkOracle).decimals()

Is called by:
- (owner; requires OracleType.CHAINLINK)

---

### setOracle, setMaxChainlinkOracleTimeDelay
Storage Slots Read:
- cTokenOracle / maxChainlinkOracleTimeDelay

Storage Slots Written:
- cTokenOracle / maxChainlinkOracleTimeDelay

Calls:
- onlyOwner check

Is called by:
- (owner)

---

## CashKYCSenderReceiver.sol

### initialize (4-arg)
Storage Slots Read:
- (initializer guard)

Storage Slots Written:
- name, symbol, decimals (ERC20)
- DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE (AccessControl)
- kycRegistry (KYCRegistryClientInitializable)
- kycRequirementGroup

Calls:
- __ERC20PresetMinterPauser_init(name, symbol)
- __KYCRegistryClientInitializable_init(kycRegistry, kycRequirementGroup)
- _disableInitializers() (in constructor)

Is called by:
- (proxy deployer, once via initializer)

---

### _beforeTokenTransfer (internal hook)
Storage Slots Read:
- kycRegistry
- kycRequirementGroup
- paused

Storage Slots Written:
- (none)

Calls:
- super._beforeTokenTransfer (ERC20PresetMinterPauserUpgradeable)
- _getKYCStatus(_msgSender())
- _getKYCStatus(from)
- _getKYCStatus(to)
- KYCRegistry.getKYCStatus(kycRequirementGroup, account)
- ISanctionsList.isSanctioned(account)

Is called by:
- transfer, transferFrom, mint, burn, burnFrom (ERC20 hooks)

---

### transfer / transferFrom
Storage Slots Read:
- balances (ERC20)
- allowances (ERC20 for transferFrom)
- kycRegistry, kycRequirementGroup, paused

Storage Slots Written:
- balances (ERC20)
- allowances (ERC20 for transferFrom)

Calls:
- _beforeTokenTransfer (KYC checks)
- KYCRegistry.getKYCStatus

Is called by:
- (KYC'd users)
- CashManager internally via cash.mint / burnFrom

---

### mint
Storage Slots Read:
- MINTER_ROLE (AccessControl)
- kycRegistry, kycRequirementGroup, paused, balances

Storage Slots Written:
- balances[to]
- totalSupply

Calls:
- onlyRole(MINTER_ROLE) (AccessControl check)
- _beforeTokenTransfer(address(0), to, amount) (KYC)
- KYCRegistry.getKYCStatus(to)

Is called by:
- CashManager.claimMint
- CashManager._processRefund

---

### burn / burnFrom
Storage Slots Read:
- balances, allowances
- kycRegistry, kycRequirementGroup, paused

Storage Slots Written:
- balances, allowances, totalSupply

Calls:
- _beforeTokenTransfer
- KYCRegistry.getKYCStatus

Is called by:
- CashManager.requestRedemption (burnFrom)
- (KYC'd users for self-burn)

---

### setKYCRegistry / setKYCRequirementGroup
Storage Slots Read:
- KYC_CONFIGURER_ROLE (AccessControl)

Storage Slots Written:
- kycRegistry / kycRequirementGroup

Calls:
- onlyRole(KYC_CONFIGURER_ROLE) check
- _setKYCRegistry / _setKYCRequirementGroup

Is called by:
- (KYC_CONFIGURER_ROLE holder)

---

## CCashDelegate.sol (inherits CCash -> CTokenCash)

### initialize (CCash override)
Storage Slots Read:
- admin (must be msg.sender)
- accrualBlockNumber, borrowIndex

Storage Slots Written:
- underlying
- initialExchangeRateMantissa
- comptroller
- accrualBlockNumber
- borrowIndex
- interestRateModel
- name, symbol, decimals
- _notEntered
- kycRegistry, kycRequirementGroup

Calls:
- super.initialize (CTokenCash.initialize)
- _setComptroller(comptroller_)
- _setInterestRateModelFresh(interestRateModel_)
- EIP20Interface(underlying).totalSupply() (sanity check)
- interestRateModel.getBorrowRate (via _setInterestRateModelFresh)
- comptroller.isComptroller()

Is called by:
- (admin == address(0) for bare delegate — UNREACHABLE without wiring)

---

### mint (CCash)
Storage Slots Read:
- accrualBlockNumber
- initialExchangeRateMantissa / totalSupply
- kycRegistry, kycRequirementGroup
- comptroller, interestRateModel
- totalBorrows, totalReserves

Storage Slots Written:
- totalSupply
- accountTokens[minter]
- accrualBlockNumber, borrowIndex, totalBorrows, totalReserves (via accrueInterest)

Calls:
- accrueInterest() -> interestRateModel.getBorrowRate() [REVERTS if IRM=address(0)]
- mintFresh(msg.sender, mintAmount)
- _getKYCStatus(minter) -> KYCRegistry.getKYCStatus
- comptroller.mintAllowed
- doTransferIn(minter, mintAmount) -> ERC20.transferFrom

Is called by:
- (external KYC'd users; blocked — bare delegate)

---

### redeem / redeemUnderlying (CCash)
Storage Slots Read:
- accrualBlockNumber, totalSupply, accountTokens
- totalBorrows, totalReserves, initialExchangeRateMantissa

Storage Slots Written:
- totalSupply, accountTokens[redeemer]
- accrualBlockNumber, borrowIndex, totalBorrows, totalReserves (via accrueInterest)

Calls:
- accrueInterest() [REVERTS if IRM=address(0)]
- _getKYCStatus(redeemer)
- comptroller.redeemAllowed
- comptroller.redeemVerify
- doTransferOut(redeemer, redeemAmount)

Is called by:
- (external KYC'd users; blocked — bare delegate)

---

### borrow (CCash)
Storage Slots Read:
- accountBorrows, totalBorrows, borrowIndex
- accrualBlockNumber
- kycRegistry, kycRequirementGroup

Storage Slots Written:
- accountBorrows[borrower].principal
- accountBorrows[borrower].interestIndex
- totalBorrows
- accrualBlockNumber, borrowIndex, totalBorrows, totalReserves (via accrueInterest)

Calls:
- accrueInterest() [REVERTS if IRM=address(0)]
- _getKYCStatus(borrower)
- comptroller.borrowAllowed
- doTransferOut(borrower, borrowAmount)

Is called by:
- (external KYC'd users; blocked — bare delegate)

---

### repayBorrow / repayBorrowBehalf (CCash)
Storage Slots Read:
- accountBorrows, totalBorrows, borrowIndex
- accrualBlockNumber

Storage Slots Written:
- accountBorrows[borrower].principal
- accountBorrows[borrower].interestIndex
- totalBorrows
- accrualBlockNumber, borrowIndex, totalBorrows, totalReserves (via accrueInterest)

Calls:
- accrueInterest() [REVERTS if IRM=address(0)]
- _getKYCStatus(payer), _getKYCStatus(borrower)
- comptroller.repayBorrowAllowed
- doTransferIn(payer, repayAmount)

Is called by:
- (external KYC'd users; blocked — bare delegate)

---

### liquidateBorrow (CCash)
Storage Slots Read:
- accrualBlockNumber, accountBorrows, totalBorrows

Storage Slots Written:
- accountBorrows, totalBorrows
- totalSupply, totalReserves, accountTokens (via seize)

Calls:
- accrueInterest() [REVERTS if IRM=address(0)]
- cTokenCollateral.accrueInterest()
- comptroller.liquidateBorrowAllowed
- comptroller.liquidateCalculateSeizeTokens
- cTokenCollateral.seize(liquidator, borrower, seizeTokens)
- repayBorrowFresh

Is called by:
- (external callers; blocked — bare delegate)

---

### seize (CCash)
Storage Slots Read:
- accountTokens[borrower], totalSupply, totalReserves
- kycRegistry, kycRequirementGroup

Storage Slots Written:
- totalReserves
- totalSupply
- accountTokens[borrower]
- accountTokens[liquidator]

Calls:
- _getKYCStatus(liquidator), _getKYCStatus(borrower)
- comptroller.seizeAllowed

Is called by:
- (another cToken during liquidation; blocked — bare delegate)

---

### approve / transfer / transferFrom (CCash/CTokenCash)
Storage Slots Read:
- transferAllowances, accountTokens
- comptroller
- kycRegistry, kycRequirementGroup

Storage Slots Written:
- transferAllowances (approve)
- accountTokens[src], accountTokens[dst]

Calls:
- comptroller.transferAllowed [REVERTS if comptroller=address(0)]
- _getKYCStatus(spender/src/dst)

Is called by:
- (KYC'd users; blocked — bare delegate, no comptroller)

---

### accrueInterest (CCash)
Storage Slots Read:
- accrualBlockNumber, totalBorrows, totalReserves, borrowIndex
- interestRateModel

Storage Slots Written:
- accrualBlockNumber, borrowIndex, totalBorrows, totalReserves

Calls:
- interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior) [REVERTS if IRM=address(0)]
- getCashPrior() -> ERC20.balanceOf

Is called by:
- mintInternal, redeemInternal, borrowInternal, repayBorrowInternal, liquidateBorrowInternal, exchangeRateCurrent, totalBorrowsCurrent, borrowBalanceCurrent

---

### Admin functions (_setReserveFactor, _reduceReserves, _acceptAdmin, _becomeImplementation, _resignImplementation)
Storage Slots Read/Written:
- admin, pendingAdmin, reserveFactorMantissa, totalReserves

Calls:
- admin check (msg.sender == admin)

Is called by:
- (admin; blocked — admin == address(0) on bare delegate)

---

## CTokenDelegate.sol (inherits CErc20 -> CTokenModified)

Note: CTokenDelegate has the same structure as CCashDelegate but uses CTokenModified base which:
- Checks sanctions list (ISanctionsList) instead of KYC for transferTokens
- mintFresh/redeemFresh/borrowFresh check sanctions via ISanctionsList
- Same Comptroller/IRM dependencies

### All functions
(Mirror CCashDelegate — same storage layout, same function signatures)

Key difference in CTokenModified vs CTokenCash:
- transferTokens checks `sanctionsList.isSanctioned(spender/src/dst)` (not KYC) for blocking
- mintFresh/redeemFresh/borrowFresh do NOT check KYC (only sanctions)
- repayBorrowFresh checks `_getKYCStatus(payer)` and `_getKYCStatus(borrower)` (KYC check present)

All lending state-changing functions REVERT on bare delegate (IRM=address(0)).

---

## PROTOCOL CHARACTERISTICS

### 4a: Multi-Actor Detection
MULTI_ACTOR: true
Evidence:
- CashManager.completeRedemptions takes `address[] calldata redeemers` and `address[] calldata refundees` — explicit multi-actor redemption distribution
- KYCRegistry manages KYC status for many addresses
- CashManager distinguishes msg.sender (minter), assetRecipient, feeRecipient, assetSender as distinct roles
- CashKYCSenderReceiver.transfer/transferFrom moves tokens between distinct KYC'd addresses

### 4b: Time-Based Logic Detection
TIME_BASED: true
TIME_PATTERN: epoch
Evidence:
- CashManager.transitionEpoch() uses `block.timestamp` and `epochDuration` to advance epochs
- currentEpochStartTimestamp is set via `block.timestamp - (block.timestamp % epochDuration)`
- setMintExchangeRate requires `epochToSet < currentEpoch` (past epoch check)
- OndoPriceOracleV2.getChainlinkOraclePrice checks `updatedAt >= block.timestamp - maxChainlinkOracleTimeDelay`
- CTokenCash.accrueInterest uses `block.number` (block-based accrual)

### 4c: Cross-Contract Dependency Detection
CROSS_CONTRACT: true
Evidence:
- CashManager reads KYCRegistry.getKYCStatus for every user action
- CashKYCSenderReceiver._beforeTokenTransfer calls KYCRegistry.getKYCStatus
- CashManager.claimMint calls cash.mint (CashKYCSenderReceiver)
- CashManager.requestRedemption calls cash.burnFrom (CashKYCSenderReceiver)
- CCashDelegate/CTokenDelegate call comptroller.mintAllowed/redeemAllowed/borrowAllowed (Compound)
- CCashDelegate/CTokenDelegate call interestRateModel.getBorrowRate
- OndoPriceOracleV2 calls cTokenOracle.getUnderlyingPrice (COMPOUND path) and chainlink oracle

### Protocol Type Classification
PROTOCOL_TYPE: VAULT
SECONDARY_TYPE: LENDING
Classification Evidence:
- deposit() pattern: requestMint deposits collateral and queues a mint request (vault deposit signal)
- withdraw() pattern: requestRedemption burns CASH and queues redemption (vault withdrawal signal)
- shares/assets conversion: _getMintAmountForEpoch(collateralDeposited, epoch) computes cashOwed = amountE24 / epochToExchangeRate (share/asset conversion)
- Off-chain exchange rate set by admin (SETTER_ADMIN) — oracle-backed NAV for vault
- borrow() / liquidate() in CCashDelegate/CTokenDelegate (LENDING signals)
- Interest rate model (IRM) via InterestRateModel.getBorrowRate (LENDING signal)
- KYC-gated access (not standard AMM/staking)
Confidence: HIGH (3+ vault signals + 2+ lending signals)

### 4e: Token Assumption Analysis
TOKEN_ASSUMPTION: RESTRICTED
Evidence:
- All CASH token transfers require KYC of msg.sender, from, and to (CashKYCSenderReceiver._beforeTokenTransfer)
- CashManager requestMint/requestRedemption gated by checkKYC modifier
- completeRedemptions KYC-checks all redeemers and refundees
- cToken operations check KYC or sanctions status on minter/redeemer/borrower

### 4f: Protocol-Issued Token Detection
ISSUES_TOKENS: true
Token Contracts:
- CashKYCSenderReceiver (CASH token, 18 decimals) — minted by CashManager.claimMint, burned by CashManager.requestRedemption

### 4g: State Machine & Lifecycle Detection
HAS_INITIALIZER: true
- CashKYCSenderReceiver: initialize(name, symbol, kycRegistry, kycRequirementGroup) — proxy initializer
- CCashDelegate/CTokenDelegate: initialize(underlying, comptroller, IRM, ...) — Compound market initializer

HAS_PAUSE: true
- CashManager: pause() / unpause() — pauses mint/redeem/multiexcall
- CashKYCSenderReceiver: pause() / unpause() — pauses ERC20 transfers

USES_UPGRADEABLE_PROXY: true
- CashKYCSenderReceiver deployed behind ERC1967Proxy
- CCashDelegate/CTokenDelegate follow Compound delegate pattern (cErc20ModifiedDelegator proxy)

### 4h: Access Control Inventory

| Function | Contract | Required Role/Condition |
|----------|----------|------------------------|
| requestMint | CashManager | checkKYC(msg.sender), whenNotPaused |
| claimMint | CashManager | checkKYC(user), whenNotPaused |
| requestRedemption | CashManager | checkKYC(msg.sender), whenNotPaused |
| setMintExchangeRate | CashManager | SETTER_ADMIN |
| overrideExchangeRate | CashManager | MANAGER_ADMIN |
| completeRedemptions | CashManager | MANAGER_ADMIN |
| setPendingMintBalance | CashManager | MANAGER_ADMIN |
| setPendingRedemptionBalance | CashManager | MANAGER_ADMIN |
| setMintExchangeRateDeltaLimit | CashManager | MANAGER_ADMIN |
| setMintFee | CashManager | MANAGER_ADMIN |
| setMinimumDepositAmount | CashManager | MANAGER_ADMIN |
| setFeeRecipient | CashManager | MANAGER_ADMIN |
| setAssetRecipient | CashManager | MANAGER_ADMIN |
| setAssetSender | CashManager | MANAGER_ADMIN |
| setRedeemMinimum | CashManager | MANAGER_ADMIN |
| setMintLimit | CashManager | MANAGER_ADMIN |
| setRedeemLimit | CashManager | MANAGER_ADMIN |
| setEpochDuration | CashManager | MANAGER_ADMIN |
| setKYCRequirementGroup | CashManager | MANAGER_ADMIN |
| setKYCRegistry | CashManager | MANAGER_ADMIN |
| pause | CashManager | PAUSER_ADMIN |
| unpause | CashManager | MANAGER_ADMIN |
| multiexcall | CashManager | MANAGER_ADMIN + whenPaused |
| addKYCAddresses | KYCRegistry | kycGroupRoles[group] role |
| removeKYCAddresses | KYCRegistry | kycGroupRoles[group] role |
| assignRoletoKYCGroup | KYCRegistry | REGISTRY_ADMIN |
| setPrice | OndoPriceOracleV2 | owner (Ownable) |
| setFTokenToOracleType | OndoPriceOracleV2 | owner |
| setPriceCap | OndoPriceOracleV2 | owner |
| setFTokenToCToken | OndoPriceOracleV2 | owner |
| setFTokenToChainlinkOracle | OndoPriceOracleV2 | owner |
| setOracle | OndoPriceOracleV2 | owner |
| setMaxChainlinkOracleTimeDelay | OndoPriceOracleV2 | owner |
| mint | CashKYCSenderReceiver | MINTER_ROLE |
| pause (token) | CashKYCSenderReceiver | PAUSER_ROLE |
| setKYCRegistry (token) | CashKYCSenderReceiver | KYC_CONFIGURER_ROLE |
| setKYCRequirementGroup (token) | CashKYCSenderReceiver | KYC_CONFIGURER_ROLE |
| _becomeImplementation | CCashDelegate/CTokenDelegate | admin |
| _resignImplementation | CCashDelegate/CTokenDelegate | admin |
| _acceptAdmin | CCashDelegate/CTokenDelegate | pendingAdmin |
| _setReserveFactor | CCashDelegate/CTokenDelegate | admin |
| _reduceReserves | CCashDelegate/CTokenDelegate | admin |
| initialize | CCashDelegate/CTokenDelegate | msg.sender == admin (address(0) on bare) |
