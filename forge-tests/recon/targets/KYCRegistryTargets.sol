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

    /// @notice Shortcut: addKYCAddressViaSignature using the pre-stored private key from Setup
    ///         The keyed actor (userPrivateKey / user) must hold the kycGroupRoles[KYC_GROUP] role.
    ///         Exercises the EIP-712 ECDSA path (line 79-112 of KYCRegistry.sol).
    ///         Requires: kYCRegistry.kycGroupRoles[KYC_GROUP] == REGISTRY_ADMIN &&
    ///                   user holds REGISTRY_ADMIN role (granted to address(this) which is admin)
    ///         NOTE: user does NOT hold REGISTRY_ADMIN in Setup (address(this) does).
    ///         This shortcut exercises the path with a user that IS the signer == address(this),
    ///         using vm.sign on behalf of the harness private key is not directly available.
    ///         We document the pattern here; to fully exercise this path, grant REGISTRY_ADMIN to
    ///         a vm.addr(userPrivateKey) and sign with vm.sign(userPrivateKey, digest).
    function shortcut_kycViaSignature(address targetUser, uint256 deadlineOffset) public updateGhosts {
        // Only exercise if targetUser is not already KYC'd
        if (kYCRegistry.kycState(KYC_GROUP, targetUser)) return;
        if (deadlineOffset == 0) deadlineOffset = 1 days;
        uint256 deadline = block.timestamp + (deadlineOffset % 30 days);

        // Build the typed data hash
        bytes32 structHash = keccak256(
            abi.encode(
                kYCRegistry._APPROVAL_TYPEHASH(),
                KYC_GROUP,
                targetUser,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", kYCRegistry.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign with pre-stored userPrivateKey
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // v must be 27 or 28 per the contract check
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return;

        // The signer will be `user` (= vm.addr(userPrivateKey))
        // For this to succeed, kycGroupRoles[KYC_GROUP] must be a role that `user` holds.
        // In Setup, REGISTRY_ADMIN is assigned to KYC_GROUP and address(this) holds it.
        // We grant REGISTRY_ADMIN to `user` temporarily so this call can succeed.
        kYCRegistry.grantRole(kYCRegistry.REGISTRY_ADMIN(), user);

        try kYCRegistry.addKYCAddressViaSignature(KYC_GROUP, targetUser, deadline, v, r, s) {} catch {}

        // Revoke the temporary grant
        kYCRegistry.revokeRole(kYCRegistry.REGISTRY_ADMIN(), user);
    }

    // === CLAMPED HANDLERS ===

    /// @notice Clamped addKYCAddressViaSignature: group pinned to KYC_GROUP, deadline clamped to 30 days from now
    function kYCRegistry_addKYCAddressViaSignature_clamped(address targetUser, uint256 deadlineOffset) public {
        uint256 deadline = block.timestamp + (deadlineOffset % (30 days + 1));
        // Build EIP-712 digest
        bytes32 structHash = keccak256(
            abi.encode(
                kYCRegistry._APPROVAL_TYPEHASH(),
                KYC_GROUP,
                targetUser,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", kYCRegistry.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        if (v < 27) v += 27;
        kYCRegistry_addKYCAddressViaSignature(KYC_GROUP, targetUser, deadline, v, r, s);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function kYCRegistry_addKYCAddressViaSignature(uint256 kycRequirementGroup, address user, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public trackOp(SelectorStorage.KYCREGISTRY_ADD_KYC_ADDRESS_VIA_SIGNATURE) asActor {
        kYCRegistry.addKYCAddressViaSignature(kycRequirementGroup, user, deadline, v, r, s);
    }

    function kYCRegistry_renounceRole(bytes32 role, address account) public trackOp(SelectorStorage.KYCREGISTRY_RENOUNCE_ROLE) asActor {
        kYCRegistry.renounceRole(role, account);
    }
}
