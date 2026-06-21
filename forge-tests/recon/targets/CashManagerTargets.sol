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
