// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "contracts/lending/chainlink/AggregatorV3Interface.sol";

/// @notice Minimal Chainlink AggregatorV3 mock for the OndoPriceOracleV2
///         CHAINLINK price path.
/// @dev updatedAt is always block.timestamp so the oracle's staleness check
///      (updatedAt >= block.timestamp - maxChainlinkOracleTimeDelay) passes
///      even after vm.warp. answeredInRound >= roundId by construction.
/// @custom:audit getChainlinkOraclePrice enforces freshness and
///        answeredInRound>=roundId; a static mock must keep updatedAt current
///        after time warps or the staleness check reverts.
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public answer = 1e8; // $1 at 8 decimals
    uint8 public constant DEC = 8;

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function decimals() external pure override returns (uint8) {
        return DEC;
    }

    function description() external pure override returns (string memory) {
        return "MockAggregatorV3";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, answer, block.timestamp, block.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }
}
