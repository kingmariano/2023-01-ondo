// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "contracts/lending/tokens/cErc20Delegate/InterestRateModel.sol";

/// @notice Minimal mock InterestRateModel for GROUP A Compound market wiring.
///         Returns a tiny but non-zero borrow rate so accrueInterest can succeed.
///         Returning 0 is also fine for basic coverage (no interest accumulates).
contract MockInterestRateModel is InterestRateModel {
    // isInterestRateModel = true is already declared in InterestRateModel as a constant

    // ~0.1% APR in per-block terms (1e18 / 2102400 blocks per year / 1000)
    uint256 public constant BORROW_RATE = 4756468797; // ~0.015% APR per block

    function getBorrowRate(
        uint /*cash*/,
        uint /*borrows*/,
        uint /*reserves*/
    ) external view override returns (uint) {
        return BORROW_RATE;
    }

    function getSupplyRate(
        uint /*cash*/,
        uint /*borrows*/,
        uint /*reserves*/,
        uint /*reserveFactorMantissa*/
    ) external view override returns (uint) {
        return BORROW_RATE / 2;
    }
}
