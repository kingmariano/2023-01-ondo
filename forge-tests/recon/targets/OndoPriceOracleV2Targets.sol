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

import "contracts/lending/OndoPriceOracleV2.sol";

abstract contract OndoPriceOracleV2Targets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function ondoPriceOracleV2_renounceOwnership() public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_RENOUNCE_OWNERSHIP) asActor {
        ondoPriceOracleV2.renounceOwnership();
    }

    function ondoPriceOracleV2_setFTokenToCToken(address fToken, address cToken) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_F_TOKEN_TO_C_TOKEN) asActor {
        ondoPriceOracleV2.setFTokenToCToken(fToken, cToken);
    }

    function ondoPriceOracleV2_setFTokenToChainlinkOracle(address fToken, address newChainlinkOracle) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_F_TOKEN_TO_CHAINLINK_ORACLE) asActor {
        ondoPriceOracleV2.setFTokenToChainlinkOracle(fToken, newChainlinkOracle);
    }

    function ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay(uint256 _maxChainlinkOracleTimeDelay) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_MAX_CHAINLINK_ORACLE_TIME_DELAY) asActor {
        ondoPriceOracleV2.setMaxChainlinkOracleTimeDelay(_maxChainlinkOracleTimeDelay);
    }

    function ondoPriceOracleV2_setOracle(address newOracle) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_ORACLE) asActor {
        ondoPriceOracleV2.setOracle(newOracle);
    }

    function ondoPriceOracleV2_setPrice(address fToken, uint256 price) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_PRICE) asActor {
        ondoPriceOracleV2.setPrice(fToken, price);
    }

    function ondoPriceOracleV2_setPriceCap(address fToken, uint256 value) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_SET_PRICE_CAP) asActor {
        ondoPriceOracleV2.setPriceCap(fToken, value);
    }

    function ondoPriceOracleV2_transferOwnership(address newOwner) public trackOp(SelectorStorage.ONDO_PRICE_ORACLE_V2_TRANSFER_OWNERSHIP) asActor {
        ondoPriceOracleV2.transferOwnership(newOwner);
    }
}