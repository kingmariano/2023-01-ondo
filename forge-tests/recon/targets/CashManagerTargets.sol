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

    /// @notice Shortcut: advances epoch by warping time forward by epochDuration
    ///         Requires: epochDuration > 0 (guaranteed by Setup)
    ///         Enables: setMintExchangeRate, overrideExchangeRate, claimMint, completeRedemptions
    function shortcut_warpAndTransitionEpoch() public updateGhosts {
        vm.warp(block.timestamp + cashManager.epochDuration());
        cashManager.transitionEpoch();
    }

    /// @notice Shortcut: full mint cycle — requestMint -> warp -> setMintExchangeRate -> claimMint
    ///         Requires: actor is KYC'd (done in Setup), collateralAmountIn above minimum
    ///         Enables: claimMint success path; generates CASH tokens for actor
    function shortcut_fullMintCycle(uint256 collateralAmountIn) public updateGhosts {
        // Clamp to valid range: must be >= minimumDepositAmount and <= mintLimit
        uint256 minDeposit = cashManager.minimumDepositAmount();
        uint256 mintLimitVal = cashManager.mintLimit();
        if (mintLimitVal == 0) return;
        collateralAmountIn = minDeposit + (collateralAmountIn % (mintLimitVal - minDeposit + 1));

        // Step 1: record which epoch we are in
        cashManager.transitionEpoch();
        uint256 epochBefore = cashManager.currentEpoch();

        // Step 2: requestMint as actor
        address actor = _getActor();
        vm.startPrank(actor);
        // Use try/catch so a revert (e.g. approval/balance too low) doesn't break the shortcut
        try cashManager.requestMint(collateralAmountIn) {} catch { vm.stopPrank(); return; }
        vm.stopPrank();

        // Step 3: advance epoch so epochBefore is now a past epoch
        vm.warp(block.timestamp + cashManager.epochDuration());
        cashManager.transitionEpoch();

        // Step 4: setMintExchangeRate for epochBefore (as admin = address(this))
        // Use lastSetMintExchangeRate to stay within delta limit
        uint256 rate = cashManager.lastSetMintExchangeRate();
        if (rate == 0) return;
        try cashManager.setMintExchangeRate(rate, epochBefore) {} catch { return; }

        // Step 5: claimMint as actor
        vm.startPrank(actor);
        try cashManager.claimMint(actor, epochBefore) {} catch {}
        vm.stopPrank();
    }

    /// @notice Shortcut: exercises requestRedemption when actor has no CASH —
    ///         first mints CASH to actor via admin mint, then calls requestRedemption
    ///         Requires: minimumRedeemAmount is set (may be 0 in Setup)
    function shortcut_mintCashThenRequestRedemption(uint256 amountCashToRedeem) public updateGhosts {
        address actor = _getActor();
        uint256 minRedeem = cashManager.minimumRedeemAmount();
        uint256 redeemLimit = cashManager.redeemLimit();
        if (redeemLimit == 0) return;
        if (amountCashToRedeem < minRedeem) amountCashToRedeem = minRedeem;
        amountCashToRedeem = minRedeem + (amountCashToRedeem % (redeemLimit - minRedeem + 1));
        if (amountCashToRedeem == 0) return;

        // Mint CASH to actor directly (admin has MINTER_ROLE via Setup)
        try cashKYCSenderReceiver.mint(actor, amountCashToRedeem) {} catch { return; }

        // Approve CashManager to burn from actor
        vm.startPrank(actor);
        cashKYCSenderReceiver.approve(address(cashManager), amountCashToRedeem);
        try cashManager.requestRedemption(amountCashToRedeem) {} catch {}
        vm.stopPrank();
    }

    /// @notice Shortcut: pause + multiexcall with empty data + unpause
    ///         Enables: multiexcall code path (requires whenPaused + MANAGER_ADMIN)
    function shortcut_pauseAndMultiexcall() public updateGhosts {
        // Pause
        cashManager.pause();
        // Call multiexcall with empty array (no-op but exercises the function)
        IMulticall.ExCallData[] memory calls = new IMulticall.ExCallData[](0);
        try cashManager.multiexcall{value: 0}(calls) {} catch {}
        // Unpause
        cashManager.unpause();
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cashManager_claimMint(address user, uint256 epochToClaim) public trackOp(SelectorStorage.CASH_MANAGER_CLAIM_MINT) asActor {
        cashManager.claimMint(user, epochToClaim);
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

    function cashManager_transitionEpoch() public trackOp(SelectorStorage.CASH_MANAGER_TRANSITION_EPOCH) asActor {
        cashManager.transitionEpoch();
    }
}
