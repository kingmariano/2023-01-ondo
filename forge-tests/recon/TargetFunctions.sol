// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {SelectorStorage} from "./SelectorStorage.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import { AdminTargets } from "./targets/AdminTargets.sol";
import { CCashDelegateTargets } from "./targets/CCashDelegateTargets.sol";
import { CTokenDelegateTargets } from "./targets/CTokenDelegateTargets.sol";
import { CashKYCSenderReceiverTargets } from "./targets/CashKYCSenderReceiverTargets.sol";
import { CashManagerTargets } from "./targets/CashManagerTargets.sol";
import { DoomsdayTargets } from "./targets/DoomsdayTargets.sol";
import { KYCRegistryTargets } from "./targets/KYCRegistryTargets.sol";
import { ManagersTargets } from "./targets/ManagersTargets.sol";
import { OndoPriceOracleV2Targets } from "./targets/OndoPriceOracleV2Targets.sol";

// Dynamic deploy contract types

abstract contract TargetFunctions is
    AdminTargets,
    CCashDelegateTargets,
    CTokenDelegateTargets,
    CashKYCSenderReceiverTargets,
    CashManagerTargets,
    DoomsdayTargets,
    KYCRegistryTargets,
    ManagersTargets,
    OndoPriceOracleV2Targets
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // =========================================================================
    // CASH Subsystem – Multi-step shortcut handlers
    // =========================================================================
    //
    // These shortcuts atomically perform prerequisite chains so the fuzzer can
    // reach hard-to-reach states in a single call instead of requiring the
    // exact multi-step sequence to be discovered organically.
    //
    // Rules followed:
    //   - `updateGhosts` modifier (not trackOp) on every shortcut
    //   - Early returns (never require) for unmet preconditions
    //   - All inputs clamped with modulo+1 or actor-balance bounds
    //   - Divide-by-zero guards (epochDuration == 0, mintLimit == 0)
    //   - vm.startPrank / vm.stopPrank for actor impersonation
    //   - try/catch so transient reverts don't brick the shortcut
    // =========================================================================

    // -------------------------------------------------------------------------
    // PATH: cashManager_setMintExchangeRate — 3 paths distinguished by rate delta
    // -------------------------------------------------------------------------

    /// PATH 0: exchangeRate < lastSetMintExchangeRate && rateDifference > maxDifferenceThisEpoch
    ///         Collapses: transitionEpoch -> setMintExchangeRate (rate below last, outside delta)
    ///         Enables:   the "rate too stale / too low" revert branch for invariant checks
    function shortcut_setMintExchangeRate_belowLast_outsideDelta(
        uint256 rateFraction
    ) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        // Warp and transition so we have a past epoch to set
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 prevEpoch = cashManager.currentEpoch() - 1;
        // Target: rate < lastSetMintExchangeRate
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        if (lastRate == 0) return;
        // Use a rate that is strictly below lastRate (fraction of it)
        uint256 rate = (rateFraction % lastRate) + 1; // 1..lastRate-1
        // Attempt — may revert if delta check passes (valid for coverage either way)
        try cashManager.setMintExchangeRate(rate, prevEpoch) {} catch {}
    }

    /// PATH 1: exchangeRate > lastSetMintExchangeRate && rateDifference <= maxDifferenceThisEpoch
    ///         Collapses: transitionEpoch -> setMintExchangeRate (rate above last, within delta)
    ///         Enables:   the happy-path rate-set with a higher rate
    function shortcut_setMintExchangeRate_aboveLast_withinDelta(
        uint256 rateBonus
    ) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 prevEpoch = cashManager.currentEpoch() - 1;
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        if (lastRate == 0) return;
        // Rate above last but within delta limit (<=BPS_DENOMINATOR basis points above)
        uint256 deltaLimit = cashManager.exchangeRateDeltaLimit();
        uint256 maxIncrease = (lastRate * deltaLimit) / cashManager.BPS_DENOMINATOR();
        uint256 bonus = (rateBonus % (maxIncrease + 1)); // 0..maxIncrease
        uint256 rate = lastRate + bonus;
        if (rate == 0) return;
        try cashManager.setMintExchangeRate(rate, prevEpoch) {} catch {}
    }

    /// PATH 2: exchangeRate == lastSetMintExchangeRate (same rate, rate == last)
    ///         Collapses: transitionEpoch -> setMintExchangeRate (same rate, outside delta check satisfied)
    ///         Enables:   the "rate equals last" exact path
    function shortcut_setMintExchangeRate_equalLast(
    ) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 prevEpoch = cashManager.currentEpoch() - 1;
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        if (lastRate == 0) return;
        // Use the exact same rate as last — satisfies exchangeRate == lastSetMintExchangeRate path
        try cashManager.setMintExchangeRate(lastRate, prevEpoch) {} catch {}
    }

    // -------------------------------------------------------------------------
    // PATH: cashManager_overrideExchangeRate — 2 paths distinguished by _lastSetMintExchangeRate
    // -------------------------------------------------------------------------

    /// PATH 0: epochToSet < currentEpoch && _lastSetMintExchangeRate != 0
    ///         Collapses: transitionEpoch -> overrideExchangeRate (with non-zero lastRate param)
    function shortcut_overrideExchangeRate_nonZeroLastRate(
        uint256 correctRate,
        uint256 overrideLastRate
    ) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 prevEpoch = cashManager.currentEpoch() - 1;
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        if (lastRate == 0) return;
        // Clamp correctRate to lastRate range (valid for override)
        correctRate = (correctRate % (lastRate + 1)) + 1;
        // overrideLastRate must be non-zero (path 0 condition)
        overrideLastRate = (overrideLastRate % (lastRate + 1)) + 1;
        try cashManager.overrideExchangeRate(correctRate, prevEpoch, overrideLastRate) {} catch {}
    }

    /// PATH 1: epochToSet < currentEpoch && _lastSetMintExchangeRate == 0
    ///         Collapses: transitionEpoch -> overrideExchangeRate with _lastSetMintExchangeRate == 0
    function shortcut_overrideExchangeRate_zeroLastRate(
        uint256 correctRate
    ) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 prevEpoch = cashManager.currentEpoch() - 1;
        uint256 lastRate = cashManager.lastSetMintExchangeRate();
        if (lastRate == 0) return;
        correctRate = (correctRate % (lastRate + 1)) + 1;
        // Pass _lastSetMintExchangeRate == 0 to hit path 1
        try cashManager.overrideExchangeRate(correctRate, prevEpoch, 0) {} catch {}
    }

    // -------------------------------------------------------------------------
    // PATH: shortcut_setRateThenClaim — transitionEpoch -> setMintExchangeRate -> claimMint
    // -------------------------------------------------------------------------

    /// @notice Shortcut: warp to new epoch, set rate for previous epoch, then claim
    ///         Collapses: transitionEpoch -> setMintExchangeRate(prevEpoch) -> claimMint
    ///         Enables:   the claimMint happy-path when a rate has already been set
    function shortcut_setRateThenClaim(uint256 epochToClaim) public updateGhosts {
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        // Advance epoch
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();
        uint256 currentEp = cashManager.currentEpoch();
        if (currentEp == 0) return;
        // Clamp epochToClaim to a past epoch
        epochToClaim = epochToClaim % currentEp; // 0..currentEp-1
        // Only set rate if not yet set
        if (cashManager.epochToExchangeRate(epochToClaim) == 0) {
            uint256 lastRate = cashManager.lastSetMintExchangeRate();
            if (lastRate == 0) return;
            try cashManager.setMintExchangeRate(lastRate, epochToClaim) {} catch { return; }
        }
        // Claim for actor
        address actor = _getActor();
        vm.startPrank(actor);
        try cashManager.claimMint(actor, epochToClaim) {} catch {}
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // PATH: shortcut_fullRedeemCycle — full redemption pipeline in one call
    // Prerequisites: mint CASH to actor -> approve -> requestRedemption ->
    //                transitionEpoch -> completeRedemptions
    // -------------------------------------------------------------------------

    /// @notice Shortcut: full redemption cycle collapsing 5 prerequisite steps
    ///         Collapses: [mint CASH] -> approve -> requestRedemption ->
    ///                    transitionEpoch -> completeRedemptions
    ///         Enables:   completeRedemptions success path; reaches payout sink
    function shortcut_fullRedeemCycle(uint256 amountCash) public updateGhosts {
        uint256 redeemLimit = cashManager.redeemLimit();
        uint256 minRedeem = cashManager.minimumRedeemAmount();
        if (redeemLimit == 0) return;
        // Clamp to [minRedeem..redeemLimit]
        if (amountCash < minRedeem) amountCash = minRedeem;
        if (amountCash > redeemLimit) amountCash = redeemLimit;
        if (amountCash == 0) return;

        address actor = _getActor();

        // Step 1: Mint CASH to actor (admin has MINTER_ROLE via Setup)
        try cashKYCSenderReceiver.mint(actor, amountCash) {} catch { return; }

        // Step 2: Actor approves CashManager to burn CASH
        vm.startPrank(actor);
        cashKYCSenderReceiver.approve(address(cashManager), amountCash);

        // Step 3: requestRedemption — burns CASH, records in current epoch
        uint256 epochBefore = cashManager.currentEpoch();
        try cashManager.requestRedemption(amountCash) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();

        // Step 4: Advance epoch so epochBefore is now a past epoch
        uint256 epochDur = cashManager.epochDuration();
        if (epochDur == 0) return;
        vm.warp(block.timestamp + epochDur);
        cashManager.transitionEpoch();

        // Step 5: completeRedemptions for actor in epochBefore
        address[] memory redeemers = new address[](1);
        redeemers[0] = actor;
        address[] memory refundees = new address[](0);
        // Collateral available in assetSender (= address(this) in Setup)
        uint256 collBal = cashManager.collateral().balanceOf(address(this));
        uint256 dist = collBal > amountCash ? amountCash : collBal;
        try cashManager.completeRedemptions(redeemers, refundees, dist, epochBefore, 0) {} catch {}
    }

    // -------------------------------------------------------------------------
    // PATH: cashManager_setPendingMintBalance — epoch <= currentEpoch after requestMint
    // -------------------------------------------------------------------------

    /// @notice Shortcut: requestMint then setPendingMintBalance for the same epoch/actor
    ///         Collapses: requestMint -> setPendingMintBalance
    ///         Enables:   setPendingMintBalance path where epoch <= currentEpoch and
    ///                    oldBalance == mintRequestsPerEpoch[epoch][user]
    function shortcut_requestMintThenSetPendingMintBalance(
        uint256 collateralAmountIn,
        uint256 newBalance
    ) public updateGhosts {
        uint256 mintLimitVal = cashManager.mintLimit();
        uint256 minDeposit = cashManager.minimumDepositAmount();
        if (mintLimitVal == 0) return;
        // Clamp collateral input
        collateralAmountIn = minDeposit + (collateralAmountIn % (mintLimitVal - minDeposit + 1));

        address actor = _getActor();
        uint256 epochBefore = cashManager.currentEpoch();

        // Step 1: requestMint
        vm.startPrank(actor);
        try cashManager.requestMint(collateralAmountIn) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();

        // Step 2: setPendingMintBalance — oldBalance must match current stored value
        uint256 oldBalance = cashManager.mintRequestsPerEpoch(epochBefore, actor);
        newBalance = newBalance % (mintLimitVal + 1);
        try cashManager.setPendingMintBalance(actor, epochBefore, oldBalance, newBalance) {} catch {}
    }

    // -------------------------------------------------------------------------
    // PATH: cashManager_setPendingRedemptionBalance — epoch <= currentEpoch, 3 paths by balance comparison
    // -------------------------------------------------------------------------

    /// PATH 0: balance > previousBalance (increase pending redemption)
    ///         Collapses: [requestRedemption to establish baseline] -> setPendingRedemptionBalance(increase)
    function shortcut_setPendingRedemptionBalance_increase(
        uint256 amountCash,
        uint256 newBalance
    ) public updateGhosts {
        address actor = _getActor();
        uint256 minRedeem = cashManager.minimumRedeemAmount();
        uint256 redeemLimit = cashManager.redeemLimit();
        if (redeemLimit == 0) return;
        if (amountCash < minRedeem) amountCash = minRedeem;
        if (amountCash > redeemLimit) amountCash = redeemLimit;
        if (amountCash == 0) return;

        // Mint CASH and request redemption to set a non-zero baseline
        try cashKYCSenderReceiver.mint(actor, amountCash) {} catch { return; }
        vm.startPrank(actor);
        cashKYCSenderReceiver.approve(address(cashManager), amountCash);
        try cashManager.requestRedemption(amountCash) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();

        uint256 epoch = cashManager.currentEpoch();
        uint256 previousBalance = cashManager.getBurnedQuantity(epoch, actor);
        // newBalance must be > previousBalance (path 0 condition)
        if (newBalance <= previousBalance) newBalance = previousBalance + 1;
        if (newBalance > redeemLimit) newBalance = redeemLimit;
        try cashManager.setPendingRedemptionBalance(actor, epoch, newBalance) {} catch {}
    }

    /// PATH 1: balance < previousBalance (decrease pending redemption)
    ///         Collapses: [requestRedemption to establish baseline] -> setPendingRedemptionBalance(decrease)
    function shortcut_setPendingRedemptionBalance_decrease(
        uint256 amountCash,
        uint256 newBalance
    ) public updateGhosts {
        address actor = _getActor();
        uint256 minRedeem = cashManager.minimumRedeemAmount();
        uint256 redeemLimit = cashManager.redeemLimit();
        if (redeemLimit == 0) return;
        if (amountCash < minRedeem) amountCash = minRedeem;
        if (amountCash > redeemLimit) amountCash = redeemLimit;
        if (amountCash == 0) return;

        // Mint CASH and request redemption to set a non-zero baseline
        try cashKYCSenderReceiver.mint(actor, amountCash) {} catch { return; }
        vm.startPrank(actor);
        cashKYCSenderReceiver.approve(address(cashManager), amountCash);
        try cashManager.requestRedemption(amountCash) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();

        uint256 epoch = cashManager.currentEpoch();
        uint256 previousBalance = cashManager.getBurnedQuantity(epoch, actor);
        if (previousBalance == 0) return; // need non-zero baseline to decrease
        // newBalance must be < previousBalance (path 1 condition)
        newBalance = newBalance % previousBalance; // 0..previousBalance-1
        try cashManager.setPendingRedemptionBalance(actor, epoch, newBalance) {} catch {}
    }

    /// PATH 2: balance == previousBalance (no-change update)
    ///         Collapses: [requestRedemption to establish baseline] -> setPendingRedemptionBalance(same)
    function shortcut_setPendingRedemptionBalance_same(
        uint256 amountCash
    ) public updateGhosts {
        address actor = _getActor();
        uint256 minRedeem = cashManager.minimumRedeemAmount();
        uint256 redeemLimit = cashManager.redeemLimit();
        if (redeemLimit == 0) return;
        if (amountCash < minRedeem) amountCash = minRedeem;
        if (amountCash > redeemLimit) amountCash = redeemLimit;
        if (amountCash == 0) return;

        // Mint CASH and request redemption to set a non-zero baseline
        try cashKYCSenderReceiver.mint(actor, amountCash) {} catch { return; }
        vm.startPrank(actor);
        cashKYCSenderReceiver.approve(address(cashManager), amountCash);
        try cashManager.requestRedemption(amountCash) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();

        uint256 epoch = cashManager.currentEpoch();
        uint256 previousBalance = cashManager.getBurnedQuantity(epoch, actor);
        // Use the exact same balance (path 2: balance == previousBalance)
        try cashManager.setPendingRedemptionBalance(actor, epoch, previousBalance) {} catch {}
    }

    // =========================================================================
    // cToken/cCash lending shortcuts — DEFERRED (bare delegates)
    // =========================================================================
    //
    // NOTE: Full lending shortcuts (cTokenDelegate_mint -> borrow -> seize,
    //       cCashDelegate_mint -> borrow -> repay, etc.) require a live
    //       Comptroller + InterestRateModel wired to delegator proxies.
    //       The bare CTokenDelegate / CCashDelegate deployed in Setup have
    //       admin == address(0) and no Comptroller, so ALL state-changing
    //       lending calls revert with "market not fresh" or "comptroller rejection".
    //       Coverage for these paths is deferred to a future phase that deploys
    //       real Compound market infrastructure.
    //
    // Placeholder marker kept here so grep can find the deferred shortcuts:
    //   shortcut_lendingMintBorrowSeize_DEFERRED
    //   shortcut_lendingMintRepay_DEFERRED
    // =========================================================================

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    /// AUTO GENERATED DYNAMIC DEPLOY SWITCHES ///
}
