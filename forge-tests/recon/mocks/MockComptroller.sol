// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "contracts/lending/tokens/cErc20Delegate/ComptrollerInterface.sol";

/// @notice Minimal mock Comptroller for GROUP A Compound market wiring.
///         Returns success (0) for all policy hooks so accrueInterest and
///         all cToken operations can proceed past the comptroller check.
///         transferAllowed, seizeAllowed, mintAllowed, etc. all return 0 = success.
contract MockComptroller is ComptrollerInterface {
    // isComptroller = true is already declared in ComptrollerInterface as a constant

    // Track which markets are supported
    mapping(address => bool) public supportedMarkets;

    // enterMarkets mapping
    mapping(address => mapping(address => bool)) public accountMembership;

    function enterMarkets(
        address[] calldata cTokens
    ) external override returns (uint[] memory errors) {
        errors = new uint[](cTokens.length);
        for (uint i = 0; i < cTokens.length; i++) {
            accountMembership[msg.sender][cTokens[i]] = true;
            errors[i] = 0; // success
        }
    }

    function exitMarket(address /*cToken*/) external override returns (uint) {
        return 0;
    }

    function mintAllowed(address /*cToken*/, address /*minter*/, uint /*mintAmount*/) external override returns (uint) {
        return 0;
    }

    function mintVerify(address /*cToken*/, address /*minter*/, uint /*mintAmount*/, uint /*mintTokens*/) external override {}

    function redeemAllowed(address /*cToken*/, address /*redeemer*/, uint /*redeemTokens*/) external override returns (uint) {
        return 0;
    }

    function redeemVerify(address /*cToken*/, address /*redeemer*/, uint /*redeemAmount*/, uint /*redeemTokens*/) external override {}

    function borrowAllowed(address /*cToken*/, address /*borrower*/, uint /*borrowAmount*/) external override returns (uint) {
        return 0;
    }

    function borrowVerify(address /*cToken*/, address /*borrower*/, uint /*borrowAmount*/) external override {}

    function repayBorrowAllowed(address /*cToken*/, address /*payer*/, address /*borrower*/, uint /*repayAmount*/) external override returns (uint) {
        return 0;
    }

    function repayBorrowVerify(address /*cToken*/, address /*payer*/, address /*borrower*/, uint /*repayAmount*/, uint /*borrowerIndex*/) external override {}

    function liquidateBorrowAllowed(
        address /*cTokenBorrowed*/,
        address /*cTokenCollateral*/,
        address /*liquidator*/,
        address /*borrower*/,
        uint /*repayAmount*/
    ) external override returns (uint) {
        return 0;
    }

    function liquidateBorrowVerify(
        address /*cTokenBorrowed*/,
        address /*cTokenCollateral*/,
        address /*liquidator*/,
        address /*borrower*/,
        uint /*repayAmount*/,
        uint /*seizeTokens*/
    ) external override {}

    function seizeAllowed(
        address /*cTokenCollateral*/,
        address /*cTokenBorrowed*/,
        address /*liquidator*/,
        address /*borrower*/,
        uint /*seizeTokens*/
    ) external override returns (uint) {
        return 0;
    }

    function seizeVerify(
        address /*cTokenCollateral*/,
        address /*cTokenBorrowed*/,
        address /*liquidator*/,
        address /*borrower*/,
        uint /*seizeTokens*/
    ) external override {}

    function transferAllowed(
        address /*cToken*/,
        address /*src*/,
        address /*dst*/,
        uint /*transferTokens*/
    ) external override returns (uint) {
        return 0;
    }

    function transferVerify(
        address /*cToken*/,
        address /*src*/,
        address /*dst*/,
        uint /*transferTokens*/
    ) external override {}

    function liquidateCalculateSeizeTokens(
        address /*cTokenBorrowed*/,
        address /*cTokenCollateral*/,
        uint /*repayAmount*/
    ) external view override returns (uint, uint) {
        return (0, 0); // no seize tokens (conservative)
    }
}
