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

import "contracts/lending/tokens/cCash/CCashDelegate.sol";
import {IERC20} from "contracts/cash/external/openzeppelin/contracts/token/IERC20.sol";

abstract contract CCashDelegateTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // === CLAMPED HANDLERS ===
    // NOTE: bare CCashDelegate has admin==address(0); most handlers will still revert
    // at runtime. Clamps are added to avoid bad-input reverts on top of that.

    /// @notice Clamped approve for cCash: amount clamped to actor's cCash balance
    function cCashDelegate_approve_clamped(uint256 amount) public {
        amount = amount % (cCashDelegate.balanceOf(_getActor()) + 1);
        cCashDelegate_approve(_getActor(), amount);
    }

    /// @notice Clamped mint for cCash: mintAmount clamped to actor's collateral balance
    function cCashDelegate_mint_clamped(uint256 mintAmount) public {
        mintAmount = mintAmount % (IERC20(collateralToken).balanceOf(_getActor()) + 1);
        cCashDelegate_mint(mintAmount);
    }

    /// @notice Clamped borrow for cCash: borrowAmount clamped to available cash in contract
    function cCashDelegate_borrow_clamped(uint256 borrowAmount) public {
        borrowAmount = borrowAmount % (cCashDelegate.getCash() + 1);
        cCashDelegate_borrow(borrowAmount);
    }

    /// @notice Clamped redeem for cCash: redeemTokens clamped to actor's cCash balance
    function cCashDelegate_redeem_clamped(uint256 redeemTokens) public {
        redeemTokens = redeemTokens % (cCashDelegate.balanceOf(_getActor()) + 1);
        cCashDelegate_redeem(redeemTokens);
    }

    /// @notice Clamped redeemUnderlying for cCash: redeemAmount clamped to actor's underlying balance
    function cCashDelegate_redeemUnderlying_clamped(uint256 redeemAmount) public {
        redeemAmount = redeemAmount % (cCashDelegate.balanceOfUnderlying(_getActor()) + 1);
        cCashDelegate_redeemUnderlying(redeemAmount);
    }

    /// @notice Clamped repayBorrow for cCash: repayAmount clamped to actor's current borrow
    function cCashDelegate_repayBorrow_clamped(uint256 repayAmount) public {
        repayAmount = repayAmount % (cCashDelegate.borrowBalanceCurrent(_getActor()) + 1);
        cCashDelegate_repayBorrow(repayAmount);
    }

    /// @notice Clamped repayBorrowBehalf for cCash: borrower pinned to actor, amount clamped to borrower's borrow
    function cCashDelegate_repayBorrowBehalf_clamped(uint256 repayAmount) public {
        address borrower = _getActor();
        repayAmount = repayAmount % (cCashDelegate.borrowBalanceCurrent(borrower) + 1);
        cCashDelegate_repayBorrowBehalf(borrower, repayAmount);
    }

    /// @notice Clamped seize for cCash: borrower pinned to actor, seizeTokens clamped to borrower balance
    function cCashDelegate_seize_clamped(uint256 seizeTokens) public {
        address borrower = _getActor();
        seizeTokens = seizeTokens % (cCashDelegate.balanceOf(borrower) + 1);
        cCashDelegate_seize(_getActor(), borrower, seizeTokens);
    }

    /// @notice Clamped transfer for cCash: dst pinned to actor, amount clamped to actor balance
    function cCashDelegate_transfer_clamped(uint256 amount) public {
        amount = amount % (cCashDelegate.balanceOf(_getActor()) + 1);
        cCashDelegate_transfer(_getActor(), amount);
    }

    /// @notice Clamped transferFrom for cCash: src/dst pinned to actor, amount clamped to allowance
    function cCashDelegate_transferFrom_clamped(address src, uint256 amount) public {
        amount = amount % (cCashDelegate.allowance(src, _getActor()) + 1);
        cCashDelegate_transferFrom(src, _getActor(), amount);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cCashDelegate__addReserves(uint256 addAmount) public trackOp(SelectorStorage.CCASH_DELEGATE__ADDRESERVES) asActor {
        cCashDelegate._addReserves(addAmount);
    }

    function cCashDelegate_accrueInterest() public trackOp(SelectorStorage.CCASH_DELEGATE_ACCRUE_INTEREST) asActor {
        cCashDelegate.accrueInterest();
    }

    function cCashDelegate_approve(address spender, uint256 amount) public trackOp(SelectorStorage.CCASH_DELEGATE_APPROVE) asActor {
        cCashDelegate.approve(spender, amount);
    }

    function cCashDelegate_balanceOfUnderlying(address owner) public trackOp(SelectorStorage.CCASH_DELEGATE_BALANCE_OF_UNDERLYING) asActor {
        cCashDelegate.balanceOfUnderlying(owner);
    }

    function cCashDelegate_borrow(uint256 borrowAmount) public trackOp(SelectorStorage.CCASH_DELEGATE_BORROW) asActor {
        cCashDelegate.borrow(borrowAmount);
    }

    function cCashDelegate_borrowBalanceCurrent(address account) public trackOp(SelectorStorage.CCASH_DELEGATE_BORROW_BALANCE_CURRENT) asActor {
        cCashDelegate.borrowBalanceCurrent(account);
    }

    function cCashDelegate_exchangeRateCurrent() public trackOp(SelectorStorage.CCASH_DELEGATE_EXCHANGE_RATE_CURRENT) asActor {
        cCashDelegate.exchangeRateCurrent();
    }

    function cCashDelegate_mint(uint256 mintAmount) public trackOp(SelectorStorage.CCASH_DELEGATE_MINT) asActor {
        cCashDelegate.mint(mintAmount);
    }

    function cCashDelegate_redeem(uint256 redeemTokens) public trackOp(SelectorStorage.CCASH_DELEGATE_REDEEM) asActor {
        cCashDelegate.redeem(redeemTokens);
    }

    function cCashDelegate_redeemUnderlying(uint256 redeemAmount) public trackOp(SelectorStorage.CCASH_DELEGATE_REDEEM_UNDERLYING) asActor {
        cCashDelegate.redeemUnderlying(redeemAmount);
    }

    function cCashDelegate_repayBorrow(uint256 repayAmount) public trackOp(SelectorStorage.CCASH_DELEGATE_REPAY_BORROW) asActor {
        cCashDelegate.repayBorrow(repayAmount);
    }

    function cCashDelegate_repayBorrowBehalf(address borrower, uint256 repayAmount) public trackOp(SelectorStorage.CCASH_DELEGATE_REPAY_BORROW_BEHALF) asActor {
        cCashDelegate.repayBorrowBehalf(borrower, repayAmount);
    }

    function cCashDelegate_seize(address liquidator, address borrower, uint256 seizeTokens) public trackOp(SelectorStorage.CCASH_DELEGATE_SEIZE) asActor {
        cCashDelegate.seize(liquidator, borrower, seizeTokens);
    }

    function cCashDelegate_totalBorrowsCurrent() public trackOp(SelectorStorage.CCASH_DELEGATE_TOTAL_BORROWS_CURRENT) asActor {
        cCashDelegate.totalBorrowsCurrent();
    }

    function cCashDelegate_transfer(address dst, uint256 amount) public trackOp(SelectorStorage.CCASH_DELEGATE_TRANSFER) asActor {
        cCashDelegate.transfer(dst, amount);
    }

    function cCashDelegate_transferFrom(address src, address dst, uint256 amount) public trackOp(SelectorStorage.CCASH_DELEGATE_TRANSFER_FROM) asActor {
        cCashDelegate.transferFrom(src, dst, amount);
    }
}