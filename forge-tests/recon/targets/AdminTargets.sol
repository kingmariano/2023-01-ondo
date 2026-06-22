// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {SelectorStorage} from "../SelectorStorage.sol";

import {IMulticall} from "contracts/cash/interfaces/IMulticall.sol";
import {IERC20} from "contracts/cash/external/openzeppelin/contracts/token/IERC20.sol";

abstract contract AdminTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // === CLAMPED HANDLERS ===

    /// @notice Clamped completeRedemptions: clamps epoch to currentEpoch, collateral amounts to
    ///         address(this) collateral balance; redeemers/refundees pinned to [actor] and []
    function cashManager_completeRedemptions_clamped(uint256 collateralAmountToDist, uint256 epochToService, uint256 fees) public {
        uint256 epoch = cashManager.currentEpoch();
        epochToService = epochToService % (epoch + 1);
        uint256 contractBal = IERC20(collateralToken).balanceOf(address(this));
        collateralAmountToDist = collateralAmountToDist % (contractBal + 1);
        fees = fees % (contractBal + 1);
        address[] memory redeemers = new address[](1);
        redeemers[0] = _getActor();
        address[] memory refundees = new address[](0);
        cashManager_completeRedemptions(redeemers, refundees, collateralAmountToDist, epochToService, fees);
    }

    /// @notice Clamped setMintExchangeRate: clamps rate to lastSetMintExchangeRate, epoch to currentEpoch
    function cashManager_setMintExchangeRate_clamped(uint256 exchangeRate, uint256 epochToSet) public {
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        exchangeRate = exchangeRate % (lastRate + 1);
        uint256 epoch = cashManager.currentEpoch();
        epochToSet = epochToSet % (epoch + 1);
        cashManager_setMintExchangeRate(exchangeRate, epochToSet);
    }

    /// @notice Clamped overrideExchangeRate: all three rate params clamped to lastSetMintExchangeRate, epoch to currentEpoch
    function cashManager_overrideExchangeRate_clamped(uint256 correctExchangeRate, uint256 epochToSet, uint256 _lastSetMintExchangeRate) public {
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        correctExchangeRate = correctExchangeRate % (lastRate + 1);
        _lastSetMintExchangeRate = _lastSetMintExchangeRate % (lastRate + 1);
        uint256 epoch = cashManager.currentEpoch();
        epochToSet = epochToSet % (epoch + 1);
        cashManager_overrideExchangeRate(correctExchangeRate, epochToSet, _lastSetMintExchangeRate);
    }

    /// @notice Clamped setMintFee: clamps fee to BPS_DENOMINATOR
    function cashManager_setMintFee_clamped(uint256 _mintFee) public {
        _mintFee = _mintFee % (cashManager.BPS_DENOMINATOR() + 1);
        cashManager_setMintFee(_mintFee);
    }

    /// @notice Clamped setMinimumDepositAmount: clamps to current mintLimit
    function cashManager_setMinimumDepositAmount_clamped(uint256 _minimumDepositAmount) public {
        _minimumDepositAmount = _minimumDepositAmount % (cashManager.mintLimit() + 1);
        cashManager_setMinimumDepositAmount(_minimumDepositAmount);
    }

    /// @notice Clamped setMintLimit: clamps to current mintLimit (keeps fuzzer in meaningful range)
    function cashManager_setMintLimit_clamped(uint256 _mintLimit) public {
        _mintLimit = _mintLimit % (cashManager.mintLimit() + 1);
        cashManager_setMintLimit(_mintLimit);
    }

    /// @notice Clamped setRedeemLimit: clamps to current redeemLimit
    function cashManager_setRedeemLimit_clamped(uint256 _redeemLimit) public {
        _redeemLimit = _redeemLimit % (cashManager.redeemLimit() + 1);
        cashManager_setRedeemLimit(_redeemLimit);
    }

    /// @notice Clamped setRedeemMinimum: clamps to current redeemLimit
    function cashManager_setRedeemMinimum_clamped(uint256 newRedeemMinimum) public {
        newRedeemMinimum = newRedeemMinimum % (cashManager.redeemLimit() + 1);
        cashManager_setRedeemMinimum(newRedeemMinimum);
    }

    /// @notice Clamped setEpochDuration: clamps to current epochDuration (avoids 0 which breaks transitionEpoch)
    function cashManager_setEpochDuration_clamped(uint256 _epochDuration) public {
        _epochDuration = _epochDuration % (cashManager.epochDuration() + 1);
        cashManager_setEpochDuration(_epochDuration);
    }

    /// @notice Clamped setMintExchangeRateDeltaLimit: clamps to BPS_DENOMINATOR
    function cashManager_setMintExchangeRateDeltaLimit_clamped(uint256 _exchangeRateDeltaLimit) public {
        _exchangeRateDeltaLimit = _exchangeRateDeltaLimit % (cashManager.BPS_DENOMINATOR() + 1);
        cashManager_setMintExchangeRateDeltaLimit(_exchangeRateDeltaLimit);
    }

    /// @notice Clamped setPendingMintBalance: epoch clamped to currentEpoch, balance to mintLimit; user pinned to actor
    function cashManager_setPendingMintBalance_clamped(uint256 epoch, uint256 oldBalance, uint256 newBalance) public {
        epoch = epoch % (cashManager.currentEpoch() + 1);
        newBalance = newBalance % (cashManager.mintLimit() + 1);
        cashManager_setPendingMintBalance(_getActor(), epoch, oldBalance, newBalance);
    }

    /// @notice Clamped setPendingRedemptionBalance: epoch clamped to currentEpoch, balance to redeemLimit; user pinned to actor
    function cashManager_setPendingRedemptionBalance_clamped(uint256 epoch, uint256 balance) public {
        epoch = epoch % (cashManager.currentEpoch() + 1);
        balance = balance % (cashManager.redeemLimit() + 1);
        cashManager_setPendingRedemptionBalance(_getActor(), epoch, balance);
    }

    /// @notice Clamped setKYCRequirementGroup: pins to the active KYC_GROUP constant
    function cashManager_setKYCRequirementGroup_clamped() public {
        cashManager_setKYCRequirementGroup(KYC_GROUP);
    }

    // === KYCRegistry clamped handlers ===

    /// @notice Clamped addKYCAddresses: pins group to KYC_GROUP, adds actor to KYC
    function kYCRegistry_addKYCAddresses_clamped() public {
        address[] memory addrs = new address[](1);
        addrs[0] = _getActor();
        kYCRegistry_addKYCAddresses(KYC_GROUP, addrs);
    }

    /// @notice Clamped assignRoletoKYCGroup: pins group to KYC_GROUP and role to REGISTRY_ADMIN
    function kYCRegistry_assignRoletoKYCGroup_clamped() public {
        kYCRegistry_assignRoletoKYCGroup(KYC_GROUP, kYCRegistry.REGISTRY_ADMIN());
    }

    // === OndoPriceOracleV2 clamped handlers ===

    /// @notice Clamped setPrice: fToken pinned to cTokenDelegate, price clamped to existing price
    function ondoPriceOracleV2_setPrice_clamped(uint256 price) public {
        address fToken = address(cTokenDelegate);
        price = price % (ondoPriceOracleV2.fTokenToUnderlyingPrice(fToken) + 1);
        ondoPriceOracleV2_setPrice(fToken, price);
    }

    /// @notice Clamped setPriceCap: fToken pinned to cTokenDelegate, value clamped to existing price
    function ondoPriceOracleV2_setPriceCap_clamped(uint256 value) public {
        address fToken = address(cTokenDelegate);
        value = value % (ondoPriceOracleV2.fTokenToUnderlyingPrice(fToken) + 1);
        ondoPriceOracleV2_setPriceCap(fToken, value);
    }

    /// @notice Clamped setMaxChainlinkOracleTimeDelay: clamps to current max delay
    function ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay_clamped(uint256 _maxChainlinkOracleTimeDelay) public {
        _maxChainlinkOracleTimeDelay = _maxChainlinkOracleTimeDelay % (ondoPriceOracleV2.maxChainlinkOracleTimeDelay() + 1);
        ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay(_maxChainlinkOracleTimeDelay);
    }

    /// @notice Clamped setFTokenToCToken: fToken pinned to cTokenDelegate
    function ondoPriceOracleV2_setFTokenToCToken_clamped(address cToken) public {
        ondoPriceOracleV2_setFTokenToCToken(address(cTokenDelegate), cToken);
    }

    /// @notice Clamped setFTokenToChainlinkOracle: fToken pinned to cTokenDelegate
    function ondoPriceOracleV2_setFTokenToChainlinkOracle_clamped(address newChainlinkOracle) public {
        ondoPriceOracleV2_setFTokenToChainlinkOracle(address(cTokenDelegate), newChainlinkOracle);
    }

    // === GROUP C: Ownable owner() + transferOwnership() handlers ===

    /// @notice Calls owner() on OndoPriceOracleV2 to cover the Ownable.owner view function.
    function ondoPriceOracleV2_owner() public {
        ondoPriceOracleV2.owner();
    }

    /// @notice Clamped transferOwnership: transfers to a known actor then immediately transfers back.
    ///         Uses vm.startPrank so the actor can call transferOwnership back to address(this).
    ///         Ensures ownership is never lost.
    function ondoPriceOracleV2_transferOwnership_clamped() public asAdmin {
        address actor = _getActor();
        // Do not transfer to address(this) (would revert in OZ Ownable if same, or is a no-op risk)
        // address(this) is the owner; transfer to a different actor
        if (actor == address(this)) return;
        // Transfer to actor
        ondoPriceOracleV2.transferOwnership(actor);
        // Transfer back from actor to address(this)
        vm.startPrank(actor);
        ondoPriceOracleV2.transferOwnership(address(this));
        vm.stopPrank();
    }

    // === GROUP C: CashKYCSenderReceiver.setKYCRegistry clamped handler ===
    // NOTE: KYC_CONFIGURER_ROLE is granted to address(this) in Setup so this succeeds.

    /// @notice Clamped setKYCRegistry: clamps registry to the known KYCRegistry address.
    function cashKYCSenderReceiver_setKYCRegistry_clamped() public asAdmin {
        cashKYCSenderReceiver_setKYCRegistry(address(kYCRegistry));
    }

    // === CCashDelegate clamped handlers (note: bare delegate; will still revert at runtime) ===

    /// @notice Clamped _setReserveFactor for cCash: clamps to reserveFactorMaxMantissa (1e18)
    function cCashDelegate__setReserveFactor_clamped(uint256 newReserveFactorMantissa) public {
        newReserveFactorMantissa = newReserveFactorMantissa % (1e18 + 1);
        cCashDelegate__setReserveFactor(newReserveFactorMantissa);
    }

    /// @notice Clamped _reduceReserves for cCash: clamps to totalReserves
    function cCashDelegate__reduceReserves_clamped(uint256 reduceAmount) public {
        reduceAmount = reduceAmount % (cCashDelegate.totalReserves() + 1);
        cCashDelegate__reduceReserves(reduceAmount);
    }

    /// @notice Clamped setKYCRequirementGroup for cCash: pins to KYC_GROUP
    function cCashDelegate_setKYCRequirementGroup_clamped() public {
        cCashDelegate_setKYCRequirementGroup(KYC_GROUP);
    }

    // === CTokenDelegate clamped handlers (note: bare delegate; will still revert at runtime) ===

    /// @notice Clamped _setReserveFactor for cToken: clamps to reserveFactorMaxMantissa (1e18)
    function cTokenDelegate__setReserveFactor_clamped(uint256 newReserveFactorMantissa) public {
        newReserveFactorMantissa = newReserveFactorMantissa % (1e18 + 1);
        cTokenDelegate__setReserveFactor(newReserveFactorMantissa);
    }

    /// @notice Clamped _reduceReserves for cToken: clamps to totalReserves
    function cTokenDelegate__reduceReserves_clamped(uint256 reduceAmount) public {
        reduceAmount = reduceAmount % (cTokenDelegate.totalReserves() + 1);
        cTokenDelegate__reduceReserves(reduceAmount);
    }

    /// @notice Clamped setKYCRequirementGroup for cToken: pins to KYC_GROUP
    function cTokenDelegate_setKYCRequirementGroup_clamped() public {
        cTokenDelegate_setKYCRequirementGroup(KYC_GROUP);
    }

    // === CashKYCSenderReceiver clamped handlers ===

    /// @notice Clamped mint: amount clamped to mintLimit; to pinned to actor
    function cashKYCSenderReceiver_mint_clamped(uint256 amount) public {
        amount = amount % (cashManager.mintLimit() + 1);
        cashKYCSenderReceiver_mint(_getActor(), amount);
    }

    /// @notice Clamped grantRole: pins role to MINTER_ROLE
    function cashKYCSenderReceiver_grantRole_clamped(address account) public {
        cashKYCSenderReceiver_grantRole(cashKYCSenderReceiver.MINTER_ROLE(), account);
    }

    /// @notice Clamped revokeRole: pins role to MINTER_ROLE
    function cashKYCSenderReceiver_revokeRole_clamped(address account) public {
        cashKYCSenderReceiver_revokeRole(cashKYCSenderReceiver.MINTER_ROLE(), account);
    }

    /// @notice Clamped setKYCRequirementGroup: pins to KYC_GROUP
    function cashKYCSenderReceiver_setKYCRequirementGroup_clamped() public {
        cashKYCSenderReceiver_setKYCRequirementGroup(KYC_GROUP);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    // === CashManager admin handlers === //

    function cashManager_completeRedemptions(address[] memory redeemers, address[] memory refundees, uint256 collateralAmountToDist, uint256 epochToService, uint256 fees) public trackOp(SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) asAdmin {
        cashManager.completeRedemptions(redeemers, refundees, collateralAmountToDist, epochToService, fees);
    }

    function cashManager_grantRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_MANAGER_GRANT_ROLE) asAdmin {
        cashManager.grantRole(role, account);
    }

    function cashManager_multiexcall(IMulticall.ExCallData[] memory exCallData) public trackOp(SelectorStorage.CASH_MANAGER_MULTIEXCALL) payable asAdmin {
        cashManager.multiexcall{value: msg.value}(exCallData);
    }

    function cashManager_overrideExchangeRate(uint256 correctExchangeRate, uint256 epochToSet, uint256 _lastSetMintExchangeRate) public trackOp(SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE) asAdmin {
        cashManager.overrideExchangeRate(correctExchangeRate, epochToSet, _lastSetMintExchangeRate);
    }

    function cashManager_pause() public trackOp(SelectorStorage.CASH_MANAGER_PAUSE) asAdmin {
        cashManager.pause();
    }

    function cashManager_revokeRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_MANAGER_REVOKE_ROLE) asAdmin {
        cashManager.revokeRole(role, account);
    }

    function cashManager_setAssetRecipient(address _assetRecipient) public trackOp(SelectorStorage.CASH_MANAGER_SET_ASSET_RECIPIENT) asAdmin {
        cashManager.setAssetRecipient(_assetRecipient);
    }

    function cashManager_setAssetSender(address newAssetSender) public trackOp(SelectorStorage.CASH_MANAGER_SET_ASSET_SENDER) asAdmin {
        cashManager.setAssetSender(newAssetSender);
    }

    function cashManager_setEpochDuration(uint256 _epochDuration) public trackOp(SelectorStorage.CASH_MANAGER_SET_EPOCH_DURATION) asAdmin {
        cashManager.setEpochDuration(_epochDuration);
    }

    function cashManager_setFeeRecipient(address _feeRecipient) public trackOp(SelectorStorage.CASH_MANAGER_SET_FEE_RECIPIENT) asAdmin {
        cashManager.setFeeRecipient(_feeRecipient);
    }

    function cashManager_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CASH_MANAGER_SET_KYC_REGISTRY) asAdmin {
        cashManager.setKYCRegistry(_kycRegistry);
    }

    function cashManager_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CASH_MANAGER_SET_KYC_REQUIREMENT_GROUP) asAdmin {
        cashManager.setKYCRequirementGroup(_kycRequirementGroup);
    }

    function cashManager_setMinimumDepositAmount(uint256 _minimumDepositAmount) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINIMUM_DEPOSIT_AMOUNT) asAdmin {
        cashManager.setMinimumDepositAmount(_minimumDepositAmount);
    }

    function cashManager_setMintExchangeRate(uint256 exchangeRate, uint256 epochToSet) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) asAdmin {
        cashManager.setMintExchangeRate(exchangeRate, epochToSet);
    }

    function cashManager_setMintExchangeRateDeltaLimit(uint256 _exchangeRateDeltaLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE_DELTA_LIMIT) asAdmin {
        cashManager.setMintExchangeRateDeltaLimit(_exchangeRateDeltaLimit);
    }

    function cashManager_setMintFee(uint256 _mintFee) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_FEE) asAdmin {
        cashManager.setMintFee(_mintFee);
    }

    function cashManager_setMintLimit(uint256 _mintLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_LIMIT) asAdmin {
        cashManager.setMintLimit(_mintLimit);
    }

    function cashManager_setPendingMintBalance(address user, uint256 epoch, uint256 oldBalance, uint256 newBalance) public trackOp(SelectorStorage.CASH_MANAGER_SET_PENDING_MINT_BALANCE) asAdmin {
        cashManager.setPendingMintBalance(user, epoch, oldBalance, newBalance);
    }

    function cashManager_setPendingRedemptionBalance(address user, uint256 epoch, uint256 balance) public trackOp(SelectorStorage.CASH_MANAGER_SET_PENDING_REDEMPTION_BALANCE) asAdmin {
        cashManager.setPendingRedemptionBalance(user, epoch, balance);
    }

    function cashManager_setRedeemLimit(uint256 _redeemLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_REDEEM_LIMIT) asAdmin {
        cashManager.setRedeemLimit(_redeemLimit);
    }

    function cashManager_setRedeemMinimum(uint256 newRedeemMinimum) public trackOp(SelectorStorage.CASH_MANAGER_SET_REDEEM_MINIMUM) asAdmin {
        cashManager.setRedeemMinimum(newRedeemMinimum);
    }

    function cashManager_unpause() public trackOp(SelectorStorage.CASH_MANAGER_UNPAUSE) asAdmin {
        cashManager.unpause();
    }

    // === KYCRegistry admin handlers === //

    function kYCRegistry_addKYCAddresses(uint256 kycRequirementGroup, address[] memory addresses) public trackOp(SelectorStorage.KYCREGISTRY_ADD_KYC_ADDRESSES) asAdmin {
        kYCRegistry.addKYCAddresses(kycRequirementGroup, addresses);
    }

    function kYCRegistry_assignRoletoKYCGroup(uint256 kycRequirementGroup, bytes32 role) public trackOp(SelectorStorage.KYCREGISTRY_ASSIGN_ROLETO_KYC_GROUP) asAdmin {
        kYCRegistry.assignRoletoKYCGroup(kycRequirementGroup, role);
    }

    function kYCRegistry_grantRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_GRANT_ROLE) asAdmin {
        kYCRegistry.grantRole(role, account);
    }

    function kYCRegistry_removeKYCAddresses(uint256 kycRequirementGroup, address[] memory addresses) public trackOp(SelectorStorage.KYCREGISTRY_REMOVE_KYC_ADDRESSES) asAdmin {
        kYCRegistry.removeKYCAddresses(kycRequirementGroup, addresses);
    }

    function kYCRegistry_revokeRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_REVOKE_ROLE) asAdmin {
        kYCRegistry.revokeRole(role, account);
    }

    // === OndoPriceOracleV2 admin handlers === //

    function ondoPriceOracleV2_renounceOwnership() public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_RENOUNCE_OWNERSHIP) asAdmin {
        ondoPriceOracleV2.renounceOwnership();
    }

    function ondoPriceOracleV2_setFTokenToCToken(address fToken, address cToken) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_F_TOKEN_TO_C_TOKEN) asAdmin {
        ondoPriceOracleV2.setFTokenToCToken(fToken, cToken);
    }

    function ondoPriceOracleV2_setFTokenToChainlinkOracle(address fToken, address newChainlinkOracle) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_F_TOKEN_TO_CHAINLINK_ORACLE) asAdmin {
        ondoPriceOracleV2.setFTokenToChainlinkOracle(fToken, newChainlinkOracle);
    }

    function ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay(uint256 _maxChainlinkOracleTimeDelay) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_MAX_CHAINLINK_ORACLE_TIME_DELAY) asAdmin {
        ondoPriceOracleV2.setMaxChainlinkOracleTimeDelay(_maxChainlinkOracleTimeDelay);
    }

    function ondoPriceOracleV2_setOracle(address newOracle) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_ORACLE) asAdmin {
        ondoPriceOracleV2.setOracle(newOracle);
    }

    function ondoPriceOracleV2_setPrice(address fToken, uint256 price) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_PRICE) asAdmin {
        ondoPriceOracleV2.setPrice(fToken, price);
    }

    function ondoPriceOracleV2_setPriceCap(address fToken, uint256 value) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_PRICE_CAP) asAdmin {
        ondoPriceOracleV2.setPriceCap(fToken, value);
    }

    function ondoPriceOracleV2_transferOwnership(address newOwner) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_TRANSFER_OWNERSHIP) asAdmin {
        ondoPriceOracleV2.transferOwnership(newOwner);
    }

    // === CCashDelegate admin handlers === //

    function cCashDelegate__acceptAdmin() public trackOp(SelectorStorage.CCASH_DELEGATE__ACCEPTADMIN) asAdmin {
        cCashDelegate._acceptAdmin();
    }

    function cCashDelegate__becomeImplementation(bytes memory data) public trackOp(SelectorStorage.CCASH_DELEGATE__BECOMEIMPLEMENTATION) asAdmin {
        cCashDelegate._becomeImplementation(data);
    }

    function cCashDelegate__delegateCompLikeTo(address compLikeDelegatee) public trackOp(SelectorStorage.CCASH_DELEGATE__DELEGATECOMPLIKETO) asAdmin {
        cCashDelegate._delegateCompLikeTo(compLikeDelegatee);
    }

    function cCashDelegate__reduceReserves(uint256 reduceAmount) public trackOp(SelectorStorage.CCASH_DELEGATE__REDUCERESERVES) asAdmin {
        cCashDelegate._reduceReserves(reduceAmount);
    }

    function cCashDelegate__resignImplementation() public trackOp(SelectorStorage.CCASH_DELEGATE__RESIGNIMPLEMENTATION) asAdmin {
        cCashDelegate._resignImplementation();
    }

    function cCashDelegate__setReserveFactor(uint256 newReserveFactorMantissa) public trackOp(SelectorStorage.CCASH_DELEGATE__SETRESERVEFACTOR) asAdmin {
        cCashDelegate._setReserveFactor(newReserveFactorMantissa);
    }

    function cCashDelegate_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CCASH_DELEGATE_SET_KYC_REGISTRY) asAdmin {
        cCashDelegate.setKYCRegistry(_kycRegistry);
    }

    function cCashDelegate_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CCASH_DELEGATE_SET_KYC_REQUIREMENT_GROUP) asAdmin {
        cCashDelegate.setKYCRequirementGroup(_kycRequirementGroup);
    }

    // === CTokenDelegate admin handlers === //

    function cTokenDelegate__acceptAdmin() public trackOp(SelectorStorage.CTOKEN_DELEGATE__ACCEPTADMIN) asAdmin {
        cTokenDelegate._acceptAdmin();
    }

    function cTokenDelegate__becomeImplementation(bytes memory data) public trackOp(SelectorStorage.CTOKEN_DELEGATE__BECOMEIMPLEMENTATION) asAdmin {
        cTokenDelegate._becomeImplementation(data);
    }

    function cTokenDelegate__delegateCompLikeTo(address compLikeDelegatee) public trackOp(SelectorStorage.CTOKEN_DELEGATE__DELEGATECOMPLIKETO) asAdmin {
        cTokenDelegate._delegateCompLikeTo(compLikeDelegatee);
    }

    function cTokenDelegate__reduceReserves(uint256 reduceAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE__REDUCERESERVES) asAdmin {
        cTokenDelegate._reduceReserves(reduceAmount);
    }

    function cTokenDelegate__resignImplementation() public trackOp(SelectorStorage.CTOKEN_DELEGATE__RESIGNIMPLEMENTATION) asAdmin {
        cTokenDelegate._resignImplementation();
    }

    function cTokenDelegate__setReserveFactor(uint256 newReserveFactorMantissa) public trackOp(SelectorStorage.CTOKEN_DELEGATE__SETRESERVEFACTOR) asAdmin {
        cTokenDelegate._setReserveFactor(newReserveFactorMantissa);
    }

    function cTokenDelegate_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CTOKEN_DELEGATE_SET_KYC_REGISTRY) asAdmin {
        cTokenDelegate.setKYCRegistry(_kycRegistry);
    }

    function cTokenDelegate_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CTOKEN_DELEGATE_SET_KYC_REQUIREMENT_GROUP) asAdmin {
        cTokenDelegate.setKYCRequirementGroup(_kycRequirementGroup);
    }

    // === CashKYCSenderReceiver admin handlers === //

    function cashKYCSenderReceiver_grantRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_GRANT_ROLE) asAdmin {
        cashKYCSenderReceiver.grantRole(role, account);
    }

    function cashKYCSenderReceiver_mint(address to, uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_MINT) asAdmin {
        cashKYCSenderReceiver.mint(to, amount);
    }

    function cashKYCSenderReceiver_pause() public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_PAUSE) asAdmin {
        cashKYCSenderReceiver.pause();
    }

    function cashKYCSenderReceiver_revokeRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_REVOKE_ROLE) asAdmin {
        cashKYCSenderReceiver.revokeRole(role, account);
    }

    function cashKYCSenderReceiver_setKYCRegistry(address registry) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_SET_KYC_REGISTRY) asAdmin {
        cashKYCSenderReceiver.setKYCRegistry(registry);
    }

    function cashKYCSenderReceiver_setKYCRequirementGroup(uint256 group) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_SET_KYC_REQUIREMENT_GROUP) asAdmin {
        cashKYCSenderReceiver.setKYCRequirementGroup(group);
    }

    function cashKYCSenderReceiver_unpause() public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_UNPAUSE) asAdmin {
        cashKYCSenderReceiver.unpause();
    }
}
