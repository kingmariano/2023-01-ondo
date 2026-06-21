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

import "contracts/cash/token/CashKYCSenderReceiver.sol";

abstract contract CashKYCSenderReceiverTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function cashKYCSenderReceiver_approve(address spender, uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_APPROVE) asActor {
        cashKYCSenderReceiver.approve(spender, amount);
    }

    function cashKYCSenderReceiver_burn(uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_BURN) asActor {
        cashKYCSenderReceiver.burn(amount);
    }

    function cashKYCSenderReceiver_burnFrom(address account, uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_BURN_FROM) asActor {
        cashKYCSenderReceiver.burnFrom(account, amount);
    }

    function cashKYCSenderReceiver_decreaseAllowance(address spender, uint256 subtractedValue) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_DECREASE_ALLOWANCE) asActor {
        cashKYCSenderReceiver.decreaseAllowance(spender, subtractedValue);
    }

    function cashKYCSenderReceiver_increaseAllowance(address spender, uint256 addedValue) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_INCREASE_ALLOWANCE) asActor {
        cashKYCSenderReceiver.increaseAllowance(spender, addedValue);
    }

    function cashKYCSenderReceiver_initialize(string memory name, string memory symbol) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_INITIALIZE_0) asActor {
        cashKYCSenderReceiver.initialize(name, symbol);
    }

    function cashKYCSenderReceiver_initialize(string memory name, string memory symbol, address kycRegistry, uint256 kycRequirementGroup) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_INITIALIZE_1) asActor {
        cashKYCSenderReceiver.initialize(name, symbol, kycRegistry, kycRequirementGroup);
    }

    function cashKYCSenderReceiver_renounceRole(bytes32 role, address account) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_RENOUNCE_ROLE) asActor {
        cashKYCSenderReceiver.renounceRole(role, account);
    }

    function cashKYCSenderReceiver_transfer(address to, uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_TRANSFER) asActor {
        cashKYCSenderReceiver.transfer(to, amount);
    }

    function cashKYCSenderReceiver_transferFrom(address from, address to, uint256 amount) public trackOp(SelectorStorage.CASH_KYC_SENDER_RECEIVER_TRANSFER_FROM) asActor {
        cashKYCSenderReceiver.transferFrom(from, to, amount);
    }
}