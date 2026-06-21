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

abstract contract CCashDelegateTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cCashDelegate__acceptAdmin() public trackOp(SelectorStorage.CCASH_DELEGATE__ACCEPTADMIN) asActor {
        cCashDelegate._acceptAdmin();
    }

    function cCashDelegate__addReserves(uint256 addAmount) public trackOp(SelectorStorage.CCASH_DELEGATE__ADDRESERVES) asActor {
        cCashDelegate._addReserves(addAmount);
    }

    function cCashDelegate__becomeImplementation(bytes memory data) public trackOp(SelectorStorage.CCASH_DELEGATE__BECOMEIMPLEMENTATION) asActor {
        cCashDelegate._becomeImplementation(data);
    }

    function cCashDelegate__delegateCompLikeTo(address compLikeDelegatee) public trackOp(SelectorStorage.CCASH_DELEGATE__DELEGATECOMPLIKETO) asActor {
        cCashDelegate._delegateCompLikeTo(compLikeDelegatee);
    }

    function cCashDelegate__reduceReserves(uint256 reduceAmount) public trackOp(SelectorStorage.CCASH_DELEGATE__REDUCERESERVES) asActor {
        cCashDelegate._reduceReserves(reduceAmount);
    }

    function cCashDelegate__resignImplementation() public trackOp(SelectorStorage.CCASH_DELEGATE__RESIGNIMPLEMENTATION) asActor {
        cCashDelegate._resignImplementation();
    }

    function cCashDelegate__setReserveFactor(uint256 newReserveFactorMantissa) public trackOp(SelectorStorage.CCASH_DELEGATE__SETRESERVEFACTOR) asActor {
        cCashDelegate._setReserveFactor(newReserveFactorMantissa);
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

    function cCashDelegate_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CCASH_DELEGATE_SET_KYC_REGISTRY) asActor {
        cCashDelegate.setKYCRegistry(_kycRegistry);
    }

    function cCashDelegate_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CCASH_DELEGATE_SET_KYC_REQUIREMENT_GROUP) asActor {
        cCashDelegate.setKYCRequirementGroup(_kycRequirementGroup);
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