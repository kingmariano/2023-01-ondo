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

abstract contract CTokenDelegateTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cTokenDelegate__acceptAdmin() public trackOp(SelectorStorage.CTOKEN_DELEGATE__ACCEPTADMIN) asActor {
        cTokenDelegate._acceptAdmin();
    }

    function cTokenDelegate__addReserves(uint256 addAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE__ADDRESERVES) asActor {
        cTokenDelegate._addReserves(addAmount);
    }

    function cTokenDelegate__becomeImplementation(bytes memory data) public trackOp(SelectorStorage.CTOKEN_DELEGATE__BECOMEIMPLEMENTATION) asActor {
        cTokenDelegate._becomeImplementation(data);
    }

    function cTokenDelegate__delegateCompLikeTo(address compLikeDelegatee) public trackOp(SelectorStorage.CTOKEN_DELEGATE__DELEGATECOMPLIKETO) asActor {
        cTokenDelegate._delegateCompLikeTo(compLikeDelegatee);
    }

    function cTokenDelegate__reduceReserves(uint256 reduceAmount) public trackOp(SelectorStorage.CTOKEN_DELEGATE__REDUCERESERVES) asActor {
        cTokenDelegate._reduceReserves(reduceAmount);
    }

    function cTokenDelegate__resignImplementation() public trackOp(SelectorStorage.CTOKEN_DELEGATE__RESIGNIMPLEMENTATION) asActor {
        cTokenDelegate._resignImplementation();
    }

    function cTokenDelegate__setReserveFactor(uint256 newReserveFactorMantissa) public trackOp(SelectorStorage.CTOKEN_DELEGATE__SETRESERVEFACTOR) asActor {
        cTokenDelegate._setReserveFactor(newReserveFactorMantissa);
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

    function cTokenDelegate_setKYCRegistry(address _kycRegistry) public trackOp(SelectorStorage.CTOKEN_DELEGATE_SET_KYC_REGISTRY) asActor {
        cTokenDelegate.setKYCRegistry(_kycRegistry);
    }

    function cTokenDelegate_setKYCRequirementGroup(uint256 _kycRequirementGroup) public trackOp(SelectorStorage.CTOKEN_DELEGATE_SET_KYC_REQUIREMENT_GROUP) asActor {
        cTokenDelegate.setKYCRequirementGroup(_kycRequirementGroup);
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