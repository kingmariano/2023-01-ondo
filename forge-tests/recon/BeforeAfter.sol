// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {SelectorStorage} from "./SelectorStorage.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {

   // Tracks which function selector is currently executing
    // Using bytes4 selector instead of enum to avoid 256 member limit
    bytes4 public currentOperation;

    struct Vars {
        uint256 __ignore__;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }


  // Sets currentOperation to the function selector before execution
    modifier trackOp(bytes4 op) {
        currentOperation = op;
        __before();
        _;
        __after();
    }

    function __before() internal {

    }

    function __after() internal {

    }
}