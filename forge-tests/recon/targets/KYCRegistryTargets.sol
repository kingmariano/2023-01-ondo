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

import "contracts/cash/kyc/KYCRegistry.sol";

abstract contract KYCRegistryTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function kYCRegistry_addKYCAddressViaSignature(uint256 kycRequirementGroup, address user, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public trackOp(SelectorStorage.KYCREGISTRY_ADD_KYC_ADDRESS_VIA_SIGNATURE) asActor {
        kYCRegistry.addKYCAddressViaSignature(kycRequirementGroup, user, deadline, v, r, s);
    }

    function kYCRegistry_addKYCAddresses(uint256 kycRequirementGroup, address[] memory addresses) public trackOp(SelectorStorage.KYCREGISTRY_ADD_KYC_ADDRESSES) asActor {
        kYCRegistry.addKYCAddresses(kycRequirementGroup, addresses);
    }

    function kYCRegistry_assignRoletoKYCGroup(uint256 kycRequirementGroup, bytes32 role) public trackOp(SelectorStorage.KYCREGISTRY_ASSIGN_ROLETO_KYC_GROUP) asActor {
        kYCRegistry.assignRoletoKYCGroup(kycRequirementGroup, role);
    }

    function kYCRegistry_grantRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_GRANT_ROLE) asActor {
        kYCRegistry.grantRole(role, account);
    }

    function kYCRegistry_removeKYCAddresses(uint256 kycRequirementGroup, address[] memory addresses) public trackOp(SelectorStorage.KYCREGISTRY_REMOVE_KYC_ADDRESSES) asActor {
        kYCRegistry.removeKYCAddresses(kycRequirementGroup, addresses);
    }

    function kYCRegistry_renounceRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_RENOUNCE_ROLE) asActor {
        kYCRegistry.renounceRole(role, account);
    }

    function kYCRegistry_revokeRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_REVOKE_ROLE) asActor {
        kYCRegistry.revokeRole(role, account);
    }
}