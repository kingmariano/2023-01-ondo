// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import {CCashDelegate} from "contracts/lending/tokens/cCash/CCashDelegate.sol";
import {CTokenDelegate} from "contracts/lending/tokens/cToken/CTokenDelegate.sol";
import {CashKYCSenderReceiver} from "contracts/cash/token/CashKYCSenderReceiver.sol";
import {CashManager} from "contracts/cash/CashManager.sol";
import {KYCRegistry} from "contracts/cash/kyc/KYCRegistry.sol";
import {OndoPriceOracleV2} from "contracts/lending/OndoPriceOracleV2.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    CCashDelegate cCashDelegate;
    CTokenDelegate cTokenDelegate;
    CashKYCSenderReceiver cashKYCSenderReceiver;
    CashManager cashManager;
    KYCRegistry kYCRegistry;
    OndoPriceOracleV2 ondoPriceOracleV2;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        cCashDelegate = new CCashDelegate(); // TODO: Add parameters here
        cTokenDelegate = new CTokenDelegate(); // TODO: Add parameters here
        cashKYCSenderReceiver = new CashKYCSenderReceiver(); // TODO: Add parameters here
        cashManager = new CashManager(); // TODO: Add parameters here
        kYCRegistry = new KYCRegistry(); // TODO: Add parameters here
        ondoPriceOracleV2 = new OndoPriceOracleV2(); // TODO: Add parameters here
    }

    /// === Dynamic deploy helpers === ///

    /// === MODIFIERS === ///
    /// Prank admin and actor

    modifier asAdmin {
        vm.startPrank(address(this));
        _;
        vm.stopPrank();
    }

    modifier asActor {
        vm.startPrank(address(_getActor()));
        _;
        vm.stopPrank();
    }
}
