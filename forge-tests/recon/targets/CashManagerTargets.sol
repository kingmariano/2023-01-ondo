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

import "contracts/cash/CashManager.sol";

abstract contract CashManagerTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cashManager_claimMint(address user, uint256 epochToClaim) public trackOp(SelectorStorage.CASH_MANAGER_CLAIM_MINT) asActor {
        cashManager.claimMint(user, epochToClaim);
    }

    function cashManager_completeRedemptions(address[] memory redeemers, address[] memory refundees, uint256 collateralAmountToDist, uint256 epochToService, uint256 fees) public trackOp(SelectorStorage.CASH_MANAGER_COMPLETE_REDEMPTIONS) asActor {
        cashManager.completeRedemptions(redeemers, refundees, collateralAmountToDist, epochToService, fees);
    }

    function cashManager_grantRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_MANAGER_GRANT_ROLE) asActor {
        cashManager.grantRole(role, account);
    }

    function cashManager_multiexcall(IMulticall.ExCallData[] memory exCallData) public trackOp(SelectorStorage.CASH_MANAGER_MULTIEXCALL) payable asActor {
        cashManager.multiexcall{value: msg.value}(exCallData);
    }

    function cashManager_overrideExchangeRate(uint256 correctExchangeRate, uint256 epochToSet, uint256 _lastSetMintExchangeRate) public trackOp(SelectorStorage.CASH_MANAGER_OVERRIDE_EXCHANGE_RATE) asActor {
        cashManager.overrideExchangeRate(correctExchangeRate, epochToSet, _lastSetMintExchangeRate);
    }

    function cashManager_pause() public trackOp(SelectorStorage.CASH_MANAGER_PAUSE) asActor {
        cashManager.pause();
    }

    function cashManager_renounceRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_MANAGER_RENOUNCE_ROLE) asActor {
        cashManager.renounceRole(role, account);
    }

    function cashManager_requestMint(uint256 collateralAmountIn) public trackOp(SelectorStorage.CASH_MANAGER_REQUEST_MINT) asActor {
        cashManager.requestMint(collateralAmountIn);
    }

    function cashManager_requestRedemption(uint256 amountCashToRedeem) public trackOp(SelectorStorage.CASH_MANAGER_REQUEST_REDEMPTION) asActor {
        cashManager.requestRedemption(amountCashToRedeem);
    }

    function cashManager_revokeRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_MANAGER_REVOKE_ROLE) asActor {
        cashManager.revokeRole(role, account);
    }

    function cashManager_setAssetRecipient(address _assetRecipient) public trackOp(SelectorStorage.CASH_MANAGER_SET_ASSET_RECIPIENT) asActor {
        cashManager.setAssetRecipient(_assetRecipient);
    }

    function cashManager_setAssetSender(address newAssetSender) public trackOp(SelectorStorage.CASH_MANAGER_SET_ASSET_SENDER) asActor {
        cashManager.setAssetSender(newAssetSender);
    }

    function cashManager_setEpochDuration(uint256 _epochDuration) public trackOp(SelectorStorage.CASH_MANAGER_SET_EPOCH_DURATION) asActor {
        cashManager.setEpochDuration(_epochDuration);
    }

    function cashManager_setFeeRecipient(address _feeRecipient) public trackOp(SelectorStorage.CASH_MANAGER_SET_FEE_RECIPIENT) asActor {
        cashManager.setFeeRecipient(_feeRecipient);
    }

    function cashManager_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CASH_MANAGER_SET_KYC_REGISTRY) asActor {
        cashManager.setKYCRegistry(_kycRegistry);
    }

    function cashManager_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CASH_MANAGER_SET_KYC_REQUIREMENT_GROUP) asActor {
        cashManager.setKYCRequirementGroup(_kycRequirementGroup);
    }

    function cashManager_setMinimumDepositAmount(uint256 _minimumDepositAmount) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINIMUM_DEPOSIT_AMOUNT) asActor {
        cashManager.setMinimumDepositAmount(_minimumDepositAmount);
    }

    function cashManager_setMintExchangeRate(uint256 exchangeRate, uint256 epochToSet) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE) asActor {
        cashManager.setMintExchangeRate(exchangeRate, epochToSet);
    }

    function cashManager_setMintExchangeRateDeltaLimit(uint256 _exchangeRateDeltaLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_EXCHANGE_RATE_DELTA_LIMIT) asActor {
        cashManager.setMintExchangeRateDeltaLimit(_exchangeRateDeltaLimit);
    }

    function cashManager_setMintFee(uint256 _mintFee) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_FEE) asActor {
        cashManager.setMintFee(_mintFee);
    }

    function cashManager_setMintLimit(uint256 _mintLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_MINT_LIMIT) asActor {
        cashManager.setMintLimit(_mintLimit);
    }

    function cashManager_setPendingMintBalance(address user, uint256 epoch, uint256 oldBalance, uint256 newBalance) public trackOp(SelectorStorage.CASH_MANAGER_SET_PENDING_MINT_BALANCE) asActor {
        cashManager.setPendingMintBalance(user, epoch, oldBalance, newBalance);
    }

    function cashManager_setPendingRedemptionBalance(address user, uint256 epoch, uint256 balance) public trackOp(SelectorStorage.CASH_MANAGER_SET_PENDING_REDEMPTION_BALANCE) asActor {
        cashManager.setPendingRedemptionBalance(user, epoch, balance);
    }

    function cashManager_setRedeemLimit(uint256 _redeemLimit) public trackOp(SelectorStorage.CASH_MANAGER_SET_REDEEM_LIMIT) asActor {
        cashManager.setRedeemLimit(_redeemLimit);
    }

    function cashManager_setRedeemMinimum(uint256 newRedeemMinimum) public trackOp(SelectorStorage.CASH_MANAGER_SET_REDEEM_MINIMUM) asActor {
        cashManager.setRedeemMinimum(newRedeemMinimum);
    }

    function cashManager_transitionEpoch() public trackOp(SelectorStorage.CASH_MANAGER_TRANSITION_EPOCH) asActor {
        cashManager.transitionEpoch();
    }

    function cashManager_unpause() public trackOp(SelectorStorage.CASH_MANAGER_UNPAUSE) asActor {
        cashManager.unpause();
    }
}