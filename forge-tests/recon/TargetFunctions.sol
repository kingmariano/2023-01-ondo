// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {SelectorStorage} from "./SelectorStorage.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import { AdminTargets } from "./targets/AdminTargets.sol";
import { CCashDelegateTargets } from "./targets/CCashDelegateTargets.sol";
import { CTokenDelegateTargets } from "./targets/CTokenDelegateTargets.sol";
import { CashKYCSenderReceiverTargets } from "./targets/CashKYCSenderReceiverTargets.sol";
import { CashManagerTargets } from "./targets/CashManagerTargets.sol";
import { DoomsdayTargets } from "./targets/DoomsdayTargets.sol";
import { KYCRegistryTargets } from "./targets/KYCRegistryTargets.sol";
import { ManagersTargets } from "./targets/ManagersTargets.sol";
import { OndoPriceOracleV2Targets } from "./targets/OndoPriceOracleV2Targets.sol";

// Dynamic deploy contract types

abstract contract TargetFunctions is
    AdminTargets,
    CCashDelegateTargets,
    CTokenDelegateTargets,
    CashKYCSenderReceiverTargets,
    CashManagerTargets,
    DoomsdayTargets,
    KYCRegistryTargets,
    ManagersTargets,
    OndoPriceOracleV2Targets
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    /// AUTO GENERATED DYNAMIC DEPLOY SWITCHES ///
}
