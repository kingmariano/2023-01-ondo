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

import "contracts/lending/tokens/cToken/CTokenDelegate.sol";
import {IERC20} from "contracts/cash/external/openzeppelin/contracts/token/IERC20.sol";

abstract contract CTokenDelegateTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // === CLAMPED HANDLERS ===
    // NOTE: bare CTokenDelegate has admin==address(0); most handlers will still revert
    // at runtime. Clamps are added to avoid bad-input reverts on top of that.

    /// @notice Clamped approve for cToken: amount clamped to actor's cToken balance
    function cTokenDelegate_approve_clamped(uint256 amount) public {
        amount = amount % (cTokenDelegate.balanceOf(_getActor()) + 1);
        cTokenDelegate_approve(_getActor(), amount);
    }

    /// @notice Clamped mint for cToken: mintAmount clamped to actor's underlying balance
    function cTokenDelegate_mint_clamped(uint256 mintAmount) public {
        mintAmount = mintAmount % (IERC20(underlyingToken).balanceOf(_getActor()) + 1);
        cTokenDelegate_mint(mintAmount);
    }

    /// @notice Clamped borrow for cToken: borrowAmount clamped to available cash in contract
    function cTokenDelegate_borrow_clamped(uint256 borrowAmount) public {
        borrowAmount = borrowAmount % (cTokenDelegate.getCash() + 1);
        cTokenDelegate_borrow(borrowAmount);
    }

    /// @notice Clamped redeem for cToken: redeemTokens clamped to actor's cToken balance
    function cTokenDelegate_redeem_clamped(uint256 redeemTokens) public {
        redeemTokens = redeemTokens % (cTokenDelegate.balanceOf(_getActor()) + 1);
        cTokenDelegate_redeem(redeemTokens);
    }

    /// @notice Clamped redeemUnderlying for cToken: redeemAmount clamped to actor's underlying balance
    function cTokenDelegate_redeemUnderlying_clamped(uint256 redeemAmount) public {
        redeemAmount = redeemAmount % (cTokenDelegate.balanceOfUnderlying(_getActor()) + 1);
        cTokenDelegate_redeemUnderlying(redeemAmount);
    }

    /// @notice Clamped repayBorrow for cToken: repayAmount clamped to actor's current borrow
    function cTokenDelegate_repayBorrow_clamped(uint256 repayAmount) public {
        repayAmount = repayAmount % (cTokenDelegate.borrowBalanceCurrent(_getActor()) + 1);
        cTokenDelegate_repayBorrow(repayAmount);
    }

    /// @notice Clamped repayBorrowBehalf for cToken: borrower pinned to actor, amount clamped to borrower's borrow
    function cTokenDelegate_repayBorrowBehalf_clamped(uint256 repayAmount) public {
        address borrower = _getActor();
        repayAmount = repayAmount % (cTokenDelegate.borrowBalanceCurrent(borrower) + 1);
        cTokenDelegate_repayBorrowBehalf(borrower, repayAmount);
    }

    /// @notice Clamped seize for cToken: borrower pinned to actor, seizeTokens clamped to borrower balance
    function cTokenDelegate_seize_clamped(uint256 seizeTokens) public {
        address borrower = _getActor();
        seizeTokens = seizeTokens % (cTokenDelegate.balanceOf(borrower) + 1);
        cTokenDelegate_seize(_getActor(), borrower, seizeTokens);
    }

    /// @notice Clamped transfer for cToken: dst pinned to actor, amount clamped to actor balance
    function cTokenDelegate_transfer_clamped(uint256 amount) public {
        amount = amount % (cTokenDelegate.balanceOf(_getActor()) + 1);
        cTokenDelegate_transfer(_getActor(), amount);
    }

    /// @notice Clamped transferFrom for cToken: src/dst pinned to actor, amount clamped to allowance
    function cTokenDelegate_transferFrom_clamped(address src, uint256 amount) public {
        amount = amount % (cTokenDelegate.allowance(src, _getActor()) + 1);
        cTokenDelegate_transferFrom(src, _getActor(), amount);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cTokenDelegate__addReserves(uint256 addAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE__ADDRESERVES) asActor {
        cTokenDelegate._addReserves(addAmount);
    }

    function cTokenDelegate_accrueInterest() public trackOp(SelectorStorage.CTOKEN_DELEGATE_ACCRUE_INTEREST) asActor {
        cTokenDelegate.accrueInterest();
    }

    function cTokenDelegate_approve(address spender, uint256 amount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_APPROVE) asActor {
        cTokenDelegate.approve(spender, amount);
    }

    function cTokenDelegate_balanceOfUnderlying(address owner) public trackOp(SelectorStorage.CTOKEN_DELEGATE_BALANCE_OF_UNDERLYING) asActor {
        cTokenDelegate.balanceOfUnderlying(owner);
    }

    function cTokenDelegate_borrow(uint256 borrowAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_BORROW) asActor {
        cTokenDelegate.borrow(borrowAmount);
    }

    function cTokenDelegate_borrowBalanceCurrent(address account) public trackOp(SelectorStorage.CTOKEN_DELEGATE_BORROW_BALANCE_CURRENT) asActor {
        cTokenDelegate.borrowBalanceCurrent(account);
    }

    function cTokenDelegate_exchangeRateCurrent() public trackOp(SelectorStorage.CTOKEN_DELEGATE_EXCHANGE_RATE_CURRENT) asActor {
        cTokenDelegate.exchangeRateCurrent();
    }

    function cTokenDelegate_mint(uint256 mintAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_MINT) asActor {
        cTokenDelegate.mint(mintAmount);
    }

    function cTokenDelegate_redeem(uint256 redeemTokens) public trackOp(SelectorStorage.CTOKEN_DELEGATE_REDEEM) asActor {
        cTokenDelegate.redeem(redeemTokens);
    }

    function cTokenDelegate_redeemUnderlying(uint256 redeemAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_REDEEM_UNDERLYING) asActor {
        cTokenDelegate.redeemUnderlying(redeemAmount);
    }

    function cTokenDelegate_repayBorrow(uint256 repayAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_REPAY_BORROW) asActor {
        cTokenDelegate.repayBorrow(repayAmount);
    }

    function cTokenDelegate_repayBorrowBehalf(address borrower, uint256 repayAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_REPAY_BORROW_BEHALF) asActor {
        cTokenDelegate.repayBorrowBehalf(borrower, repayAmount);
    }

    function cTokenDelegate_seize(address liquidator, address borrower, uint256 seizeTokens) public trackOp(SelectorStorage.CTOKEN_DELEGATE_SEIZE) asActor {
        cTokenDelegate.seize(liquidator, borrower, seizeTokens);
    }

    function cTokenDelegate_totalBorrowsCurrent() public trackOp(SelectorStorage.CTOKEN_DELEGATE_TOTAL_BORROWS_CURRENT) asActor {
        cTokenDelegate.totalBorrowsCurrent();
    }

    function cTokenDelegate_transfer(address dst, uint256 amount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_TRANSFER) asActor {
        cTokenDelegate.transfer(dst, amount);
    }

    function cTokenDelegate_transferFrom(address src, address dst, uint256 amount) public trackOp(SelectorStorage.CTOKEN_DELEGATE_TRANSFER_FROM) asActor {
        cTokenDelegate.transferFrom(src, dst, amount);
    }
}