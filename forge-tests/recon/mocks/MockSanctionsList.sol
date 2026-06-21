// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {ISanctionsList} from "contracts/cash/external/chainalysis/ISanctionsList.sol";

/// @notice Non-reverting Chainalysis sanctions list mock.
/// @dev isSanctioned returns false for every address so getKYCStatus
///      (kycState && !isSanctioned) is only gated by the registry KYC state.
/// @custom:audit getKYCStatus() ANDs kycState with !sanctionsList.isSanctioned;
///        a reverting/empty sanctions list would make every KYC check revert.
contract MockSanctionsList is ISanctionsList {
    function isSanctioned(address) external pure override returns (bool) {
        return false;
    }
}
