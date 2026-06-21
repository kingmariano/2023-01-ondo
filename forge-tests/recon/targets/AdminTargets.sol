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

abstract contract AdminTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


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
