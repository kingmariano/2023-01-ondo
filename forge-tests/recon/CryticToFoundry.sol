// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {IMulticall} from "contracts/cash/interfaces/IMulticall.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();

        // targetContract(address(this)); // StdInvariant absent in forge-std v1.1.1; Chimera uses Echidna + direct property_ calls
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        // TODO: add failing property tests here for debugging
    }

    // ============================================================
    //  Phase 3B smoke-tests
    // ============================================================

    /// SMOKE: Phase 3B static properties hold from construction
    function test_properties_3b_static() public {
        // DOOM properties: valid from construction (before any admin mis-call)
        _assertProperty(property_doom_assetSenderNotZero(),     "DOOM-FF-06: assetSender != 0");
        _assertProperty(property_doom_epochDurationNotZero(),   "DOOM-FF-07: epochDuration != 0");
        _assertProperty(property_eco_lowRateOverrideAlert(),    "ECO-02: no low override yet");
        _assertProperty(property_t11_epochOnlyAdvances(),       "T11-01: epoch non-decreasing");
        _assertProperty(property_t11_epochStartTimestampValid(),"T11-02: epoch start <= now");
        _assertProperty(property_t13_supplyNoOverflow(),        "T13-02: supply sane");
    }

    /// SMOKE: Phase 3B inline properties after a full mint cycle
    function test_properties_3b_after_mint() public {
        cashManager_requestMint(MINT_AMT);
        _assertProperty(property_delta_requestMintDepositAccounting(), "DELTA-01 post-requestMint");
        _assertProperty(property_profit_mintRequestSumConsistent(),    "PROFIT-02 post-requestMint");
        _assertProperty(property_t14_mintRequestSumMatchesOnChain(),   "T14-04 post-requestMint");

        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        _assertProperty(property_t11_epochOnlyAdvances(), "T11-01 post-transition");

        cashManager_setMintExchangeRate(1e6, 0);
        _assertProperty(property_delta_setRateUpdatesLastRate(),    "DELTA-05 post-setRate");
        _assertProperty(property_delta_autopauseOnDeltaViolation(), "DELTA-06 post-setRate");
        _assertProperty(property_t11_autopauseNoRateUpdate(),       "T11-04 post-setRate");
        _assertProperty(property_rate_deltaLimitEnforced(),         "RATE-03 post-setRate");

        cashManager_claimMint(_getActor(), 0);
        _assertProperty(property_delta_claimMintCashBalance(),  "DELTA-04 post-claim");
        _assertProperty(property_t14_cashOwedAtLeastOne(),      "T14-01 post-claim");
        _assertProperty(property_round_cashOwedRoundedDown(),   "ROUND-01 post-claim");
        _assertProperty(property_sol_mintRequestsZeroAfterClaim(), "SOL-06 post-claim");
        _assertProperty(property_profit_burnGeRefund(),         "PROFIT-05/SOL-01 post-claim");
    }

    /// SMOKE: Phase 3B properties after redemption
    function test_properties_3b_after_redemption() public {
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);
        cashManager_claimMint(_getActor(), 0);
        cashKYCSenderReceiver_approve(address(cashManager), type(uint256).max);

        cashManager_requestRedemption(1e18);
        _assertProperty(property_round_feeRoundedDown(),            "ROUND-02 post-requestRedemption");
        _assertProperty(property_profit_burnGeRefund(),             "PROFIT-05 post-requestRedemption");

        uint256 redeemEpoch = cashManager.currentEpoch();
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();

        address[] memory redeemers = new address[](1);
        redeemers[0] = _getActor();
        address[] memory refundees = new address[](0);
        cashManager_completeRedemptions(redeemers, refundees, 1e6, redeemEpoch, 0);
        _assertProperty(property_round_redemptionSumWithinDist(),          "ROUND-03 post-complete");
        _assertProperty(property_round_totalBurnedDecreaseAfterComplete(), "ROUND-04 post-complete");
        _assertProperty(property_doom_doubleServiceReverts(),               "DOOM-FF-02 post-complete");
        _assertProperty(property_ff_burnAmtNonIncreasingAfterComplete(),    "FF-02 post-complete");
    }

    /// SMOKE: T12-01 exchange rate immutability
    function test_properties_3b_rateImmutability() public {
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);
        // After setting rate for epoch 0, ghost_epochFirstRate[0] should be 1e6
        // A second call must revert (EpochExchangeRateAlreadySet)
        // T12-01: the rate for epoch 0 cannot be changed by setMintExchangeRate
        _assertProperty(property_t12_exchangeRateImmutableOnceSet(), "T12-01 post-setRate");
        // Verify it's still correct after another transition
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        _assertProperty(property_t12_exchangeRateImmutableOnceSet(), "T12-01 post-2nd-transition");
    }

    /// SMOKE: Negative privilege properties — non-admin cannot call admin functions
    function test_properties_3b_negative_privilege() public {
        // The active actor starts as address(this) which IS admin; switch to user
        // We call the properties directly — they internally prank as _getActor()
        // Force actor to user (not admin) by using vm.prank indirectly through property
        // The property checks: if actor == address(this), skip. Since actor is address(this),
        // all four will return true (skip). That's expected — they're fuzzer properties.
        // For Foundry smoke we call them to verify no compile/runtime error.
        _assertProperty(property_neg_nonAdminCannotSetMintExchangeRate(), "PRIV-NEG-01");
        _assertProperty(property_neg_nonAdminCannotPause(),               "PRIV-NEG-02");
        _assertProperty(property_neg_nonAdminCannotSetMintFee(),          "PRIV-NEG-03");
        _assertProperty(property_neg_nonAdminCannotOverrideRate(),        "PRIV-NEG-04");
        _assertProperty(property_neg_nonAdminCannotAddKYCAddresses(),     "KYC-01");
    }

    /// DOOM TEST — property_doom_assetSenderNotZero detects missing zero-address validation.
    ///             This test verifies the DOOM property CORRECTLY detects the bug.
    ///             The property should FAIL (return false) after setAssetSender(address(0)).
    function test_doom_assetSenderZero_detectsBug() public {
        // First verify it holds
        assertTrue(property_doom_assetSenderNotZero(), "Should pass initially");
        // Drive the bug DIRECTLY on the contract (msg.sender == address(this)
        // holds SETTER_ADMIN), bypassing the hooked handler so the property can
        // be inspected. Going through the handler would instead trip _afterHook's
        // t() — which is exactly what Echidna falsifies in the campaign.
        cashManager.setAssetSender(address(0));
        assertFalse(property_doom_assetSenderNotZero(), "DOOM-FF-06: detects assetSender==0 bug");
    }

    /// DOOM TEST — property_doom_epochDurationNotZero detects missing zero-duration validation.
    ///             The property should FAIL (return false) after setEpochDuration(0).
    function test_doom_epochDurationZero_detectsBug() public {
        // First verify it holds
        assertTrue(property_doom_epochDurationNotZero(), "Should pass initially");
        // Drive the bug DIRECTLY on the contract, bypassing the hooked handler
        // (the handler path trips _afterHook's t(), which is the campaign falsification).
        cashManager.setEpochDuration(0);
        assertFalse(property_doom_epochDurationNotZero(), "DOOM-FF-07: detects epochDuration==0 bug");
    }

    /// DOOM TEST — ECO-02: overrideExchangeRate can set rate to 1 (< MIN_SAFE_RATE).
    ///             The property should FAIL (return false) after override with rate=1.
    function test_doom_eco02_lowRateOverride_detectsBug() public {
        // First transition epoch so we have a past epoch to override
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);

        // Verify the floor property holds initially
        assertTrue(property_round_exchangeRateFloor(), "ROUND-06 should pass initially");

        // Override DIRECTLY with a dangerously low rate (1, well below MIN_SAFE_RATE
        // of 1e3), bypassing the hooked handler. lastSetMintExchangeRate becomes 1,
        // so the live floor property detects it. (Through the handler this trips
        // _afterHook's t() — the ECO-02/ROUND-06 falsification Echidna reports.)
        cashManager.overrideExchangeRate(1, 0, 1);
        assertFalse(property_round_exchangeRateFloor(), "ECO-02/ROUND-06: detects rate below floor");
    }

    /// DOOM TEST — overrideExchangeRate(0, epoch, 0) bricks claimMint for that epoch.
    ///             After override with rate=0, claimMint reverts with ExchangeRateNotSet.
    function test_doom_overrideRateZero_bricksClaimMint() public {
        // Setup: requestMint, transition, then override rate to 0
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);

        // Override rate to 0 for epoch 0 — this bricks claimMint
        cashManager_overrideExchangeRate(0, 0, 1e6);

        // Now try to claimMint for epoch 0 — should revert
        vm.expectRevert(); // ExchangeRateNotSet (rate == 0)
        this.cashManager_claimMint(_getActor(), 0);
    }

    // ============================================================
    //  Phase 3A — property smoke-tests (run through real scenarios
    //  and assert the property_ functions return true)
    // ============================================================

    /// Helper: assert property is true; used by property smoke-tests
    function _assertProperty(bool result, string memory name) internal pure {
        require(result, name);
    }

    /// SMOKE: static properties that hold from construction
    function test_properties_static() public {
        _assertProperty(property_fee_mintFeeBelowMax(),          "FEE-01");
        _assertProperty(property_fee_minimumDepositAboveFloor(), "FEE-06");
        _assertProperty(property_t15_pauserAdminRoleAdmin(),     "T15-05");
        _assertProperty(property_t15_setterAdminRoleAdmin(),     "T15-05b");
        _assertProperty(property_t13_decimalsMultiplierCorrect(), "T13-04");
        _assertProperty(property_t13_manualPriceNoRevert(),       "T13-05");
        _assertProperty(property_sol_mintAmountWithinLimit(),    "SOL-02");
        _assertProperty(property_sol_redeemAmountWithinLimit(),  "SOL-03");
        _assertProperty(property_rate_priceCap(),                "RATE-06");
        _assertProperty(property_rate_priceCapCCash(),           "RATE-06b");
        _assertProperty(property_round_exchangeRateFloor(),      "ROUND-06");
        _assertProperty(property_mono_epochNonDecreasing(),      "MONO-01");
        _assertProperty(property_t11_totalBurnedNonNegative(),   "T11-07");
    }

    /// SMOKE: canary booleans start as true (handlers not yet reached)
    function test_properties_canary_initial() public {
        // Canaries start as "not yet reached" (true = property holds)
        _assertProperty(property_canary_requestMintReached(),         "CANARY-01 initial");
        _assertProperty(property_canary_claimMintReached(),           "CANARY-02 initial");
        _assertProperty(property_canary_requestRedemptionReached(),   "CANARY-03 initial");
        _assertProperty(property_canary_completeRedemptionsReached(), "CANARY-04 initial");
        _assertProperty(property_canary_setRateReached(),             "CANARY-05 initial");
        _assertProperty(property_canary_overrideRateReached(),        "CANARY-06 initial");
        _assertProperty(property_canary_transitionEpochReached(),     "CANARY-07 initial");
    }

    /// SMOKE: run a full mint cycle and verify snapshot-based properties
    function test_properties_after_mint_cycle() public {
        // Full mint cycle: requestMint -> transition -> setRate -> claimMint
        cashManager_requestMint(MINT_AMT);
        // After requestMint: limits still within bounds
        _assertProperty(property_sol_mintAmountWithinLimit(), "SOL-02 post-requestMint");
        _assertProperty(property_fee_mintFeeBelowMax(),       "FEE-01 post-requestMint");

        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        // After epoch transition: canary fired, limit amounts reset
        _assertProperty(property_sol_epochResetAmounts(),     "SOL-04 post-transition");
        _assertProperty(property_mono_epochNonDecreasing(),   "MONO-01 post-transition");

        cashManager_setMintExchangeRate(1e6, 0);
        _assertProperty(property_round_exchangeRateFloor(),   "ROUND-06 post-setRate");
        _assertProperty(property_rate_priceCap(),             "RATE-06 post-setRate");

        cashManager_claimMint(_getActor(), 0);
        _assertProperty(property_profit_claimMintZeroesMintRequests(), "PROFIT-04 post-claim");
        _assertProperty(property_t13_getBurnedQuantityConsistent(),    "T13-01 post-claim");
    }

    /// SMOKE: run requestRedemption and verify delta properties
    function test_properties_after_redemption_request() public {
        // Setup: get some CASH
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);
        cashManager_claimMint(_getActor(), 0);
        cashKYCSenderReceiver_approve(address(cashManager), type(uint256).max);

        // requestRedemption
        cashManager_requestRedemption(1e18);
        _assertProperty(property_sol_redeemAmountWithinLimit(),            "SOL-03 post-redeem");
        _assertProperty(property_delta_requestRedemptionSupplyDrop(),      "DELTA-03 post-redeem");
        _assertProperty(property_delta_requestRedemptionBurnAccounting(),  "DELTA-02 post-redeem");
        _assertProperty(property_t12_redeemAmountCannotBeZero(),           "T12-07 post-redeem");
        _assertProperty(property_t13_getBurnedQuantityConsistent(),        "T13-01 post-redeem");
    }

    /// SMOKE: canary booleans flip to false after handlers are called
    function test_properties_canary_flip() public {
        // Exercise handlers to flip canaries
        cashManager_requestMint(MINT_AMT);
        // requestMint canary should now be flipped (ghost set to true => property returns false)
        assertTrue(!property_canary_requestMintReached(), "CANARY-01 should flip");

        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        assertTrue(!property_canary_transitionEpochReached(), "CANARY-07 should flip");

        cashManager_setMintExchangeRate(1e6, 0);
        assertTrue(!property_canary_setRateReached(), "CANARY-05 should flip");

        cashManager_claimMint(_getActor(), 0);
        assertTrue(!property_canary_claimMintReached(), "CANARY-02 should flip");

        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_overrideExchangeRate(1e6, 0, 1e6);
        assertTrue(!property_canary_overrideRateReached(), "CANARY-06 should flip");
    }

    /*//////////////////////////////////////////////////////////////
                    CASH MANAGER  (handler reachability)
    //////////////////////////////////////////////////////////////*/

    // Minimum deposit is 10_000 (collateral, 6 decimals). Actors are funded with
    // type(uint88).max collateral and have approved the CashManager in Setup.
    uint256 internal constant MINT_AMT = 1_000_000; // > minimumDepositAmount (10_000)

    function test_cashManager_requestMint() public {
        cashManager_requestMint(MINT_AMT);
    }

    function test_cashManager_transitionEpoch() public {
        // No-op when no time elapsed; warp so an epoch boundary is crossed too.
        cashManager_transitionEpoch();
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
    }

    function test_cashManager_setMintExchangeRate() public {
        // setMintExchangeRate requires epochToSet < currentEpoch and SETTER_ADMIN
        // (granted to address(this) in Setup).
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch(); // currentEpoch becomes 1
        cashManager_setMintExchangeRate(1e6, 0); // epoch 0 < 1, rate == lastSet (no delta)
    }

    function test_cashManager_overrideExchangeRate() public {
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_overrideExchangeRate(1e6, 0, 1e6);
    }

    function test_cashManager_claimMint() public {
        // Full mint lifecycle: requestMint -> transitionEpoch -> setMintExchangeRate -> claimMint
        cashManager_requestMint(MINT_AMT); // epoch 0
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch(); // currentEpoch -> 1
        cashManager_setMintExchangeRate(1e6, 0); // set rate for epoch 0
        cashManager_claimMint(_getActor(), 0); // claim for the requesting actor
    }

    function test_cashManager_requestRedemption() public {
        // Need: minted CASH + approval of CASH to CashManager (burnFrom).
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);
        cashManager_claimMint(_getActor(), 0);
        // Approve CASH for burnFrom inside requestRedemption.
        cashKYCSenderReceiver_approve(address(cashManager), type(uint256).max);
        cashManager_requestRedemption(1e18);
    }

    function test_cashManager_setPendingMintBalance() public {
        cashManager_requestMint(MINT_AMT);
        // oldBalance must equal current mintRequestsPerEpoch[epoch][user];
        // after requestMint of MINT_AMT (no fee) it is MINT_AMT at epoch 0.
        cashManager_setPendingMintBalance(_getActor(), 0, MINT_AMT, MINT_AMT + 1);
    }

    function test_cashManager_setPendingRedemptionBalance() public {
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch();
        cashManager_setMintExchangeRate(1e6, 0);
        cashManager_claimMint(_getActor(), 0);
        cashKYCSenderReceiver_approve(address(cashManager), type(uint256).max);
        cashManager_requestRedemption(1e18);
        cashManager_setPendingRedemptionBalance(_getActor(), cashManager.currentEpoch(), 5e17);
    }

    function test_cashManager_completeRedemptions() public {
        // Build a serviceable redemption in a past epoch, then service it.
        cashManager_requestMint(MINT_AMT);
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch(); // epoch 1
        cashManager_setMintExchangeRate(1e6, 0);
        cashManager_claimMint(_getActor(), 0);
        cashKYCSenderReceiver_approve(address(cashManager), type(uint256).max);
        cashManager_requestRedemption(1e18); // recorded at currentEpoch (1)
        uint256 redeemEpoch = cashManager.currentEpoch();
        vm.warp(block.timestamp + 1 days + 1);
        cashManager_transitionEpoch(); // advance so redeemEpoch is in the past

        address[] memory redeemers = new address[](1);
        redeemers[0] = _getActor();
        address[] memory refundees = new address[](0);
        // assetSender == address(this) holds collateral and approved CashManager.
        cashManager_completeRedemptions(redeemers, refundees, 1e6, redeemEpoch, 0);
    }

    function test_cashManager_pause_unpause() public {
        cashManager_pause();
        cashManager_unpause();
    }

    function test_cashManager_grantRole() public {
        cashManager_grantRole(cashManager.SETTER_ADMIN(), address(this));
    }

    function test_cashManager_revokeRole() public {
        cashManager_grantRole(cashManager.PAUSER_ADMIN(), address(this));
        cashManager_revokeRole(cashManager.PAUSER_ADMIN(), address(this));
    }

    function test_cashManager_renounceRole() public {
        // renounce pranks asActor (address(this)); renounce a role it holds.
        cashManager_renounceRole(cashManager.MANAGER_ADMIN(), address(this));
    }

    function test_cashManager_setters() public {
        cashManager_setAssetRecipient(address(this));
        cashManager_setAssetSender(address(this));
        cashManager_setFeeRecipient(address(this));
        cashManager_setEpochDuration(1 days);
        cashManager_setKYCRegistry(address(kYCRegistry));
        cashManager_setKYCRequirementGroup(KYC_GROUP);
        cashManager_setMinimumDepositAmount(10_000);
        cashManager_setMintExchangeRateDeltaLimit(100);
        cashManager_setMintFee(0);
        cashManager_setMintLimit(type(uint128).max);
        cashManager_setRedeemLimit(type(uint128).max);
        cashManager_setRedeemMinimum(0);
    }

    function test_cashManager_multiexcall() public {
        // multiexcall is gated by whenPaused; pause first.
        cashManager_pause();
        IMulticall.ExCallData[] memory data = new IMulticall.ExCallData[](0);
        cashManager_multiexcall(data);
    }

    /*//////////////////////////////////////////////////////////////
                            KYC REGISTRY
    //////////////////////////////////////////////////////////////*/

    function test_kYCRegistry_assignRoletoKYCGroup() public {
        kYCRegistry_assignRoletoKYCGroup(KYC_GROUP, kYCRegistry.REGISTRY_ADMIN());
    }

    function test_kYCRegistry_addKYCAddresses() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xBEEF);
        kYCRegistry_addKYCAddresses(KYC_GROUP, addrs);
    }

    function test_kYCRegistry_removeKYCAddresses() public {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xBEEF);
        kYCRegistry_addKYCAddresses(KYC_GROUP, addrs);
        kYCRegistry_removeKYCAddresses(KYC_GROUP, addrs);
    }

    function test_kYCRegistry_grantRole() public {
        kYCRegistry_grantRole(kYCRegistry.REGISTRY_ADMIN(), user);
    }

    function test_kYCRegistry_revokeRole() public {
        kYCRegistry_grantRole(kYCRegistry.REGISTRY_ADMIN(), user);
        kYCRegistry_revokeRole(kYCRegistry.REGISTRY_ADMIN(), user);
    }

    function test_kYCRegistry_renounceRole() public {
        // asActor (address(this)) holds REGISTRY_ADMIN; renounce it.
        kYCRegistry_renounceRole(kYCRegistry.REGISTRY_ADMIN(), address(this));
    }

    function test_kYCRegistry_addKYCAddressViaSignature() public {
        // Grant REGISTRY_ADMIN (the gating role for KYC_GROUP) to the keyed signer.
        kYCRegistry_grantRole(kYCRegistry.REGISTRY_ADMIN(), user);

        address newUser = address(0xCAFE); // not yet KYC'd
        uint256 deadline = block.timestamp + 1 days;
        bytes32 structHash = keccak256(
            abi.encode(kYCRegistry._APPROVAL_TYPEHASH(), KYC_GROUP, newUser, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", kYCRegistry.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        kYCRegistry_addKYCAddressViaSignature(KYC_GROUP, newUser, deadline, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                         ONDO PRICE ORACLE V2
    //////////////////////////////////////////////////////////////*/

    function test_ondoPriceOracleV2_setPrice() public {
        // MANUAL oracle type already set in Setup for the delegate as fToken.
        ondoPriceOracleV2_setPrice(address(cCashDelegate), 2e18);
    }

    function test_ondoPriceOracleV2_setPriceCap() public {
        ondoPriceOracleV2_setPriceCap(address(cCashDelegate), 5e18);
    }

    function test_ondoPriceOracleV2_setOracle() public {
        ondoPriceOracleV2_setOracle(address(ondoPriceOracleV2));
    }

    // setFTokenToCToken requires the fToken oracle type == COMPOUND (set only via
    // the owner-only setFTokenToOracleType, which is NOT exposed as a handler) AND
    // a fully wired cToken whose underlying() matches the fToken's. Both are part of
    // the deferred Compound-market wiring. Justified revert; see reverting-handlers.json.
    function test_ondoPriceOracleV2_setFTokenToCToken_reverts() public {
        vm.expectRevert(); // "OracleType must be Compound" (delegate is MANUAL)
        this.ondoPriceOracleV2_setFTokenToCToken(address(cTokenDelegate), CTOKEN_ORACLE_DEFAULT);
    }

    // setFTokenToChainlinkOracle requires oracle type == CHAINLINK (owner-only, no
    // handler) and reads fToken.underlying().decimals() — the bare delegate has no
    // underlying wired. Justified revert; see reverting-handlers.json.
    function test_ondoPriceOracleV2_setFTokenToChainlinkOracle_reverts() public {
        vm.expectRevert(); // "OracleType must be Chainlink"
        this.ondoPriceOracleV2_setFTokenToChainlinkOracle(address(cTokenDelegate), address(chainlinkOracle));
    }

    function test_ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay() public {
        ondoPriceOracleV2_setMaxChainlinkOracleTimeDelay(1 days);
    }

    function test_ondoPriceOracleV2_transferOwnership() public {
        ondoPriceOracleV2_transferOwnership(address(this));
    }

    function test_ondoPriceOracleV2_renounceOwnership() public {
        ondoPriceOracleV2_renounceOwnership();
    }

    /*//////////////////////////////////////////////////////////////
                       CASH KYC SENDER RECEIVER (token)
    //////////////////////////////////////////////////////////////*/

    function _mintCash(address to, uint256 amt) internal {
        // to must be KYC'd (mint checks `to`); address(this)/user are KYC'd in Setup.
        cashKYCSenderReceiver_mint(to, amt);
    }

    function test_cashKYCSenderReceiver_mint() public {
        _mintCash(_getActor(), 1e18);
    }

    function test_cashKYCSenderReceiver_burn() public {
        _mintCash(_getActor(), 1e18);
        cashKYCSenderReceiver_burn(5e17);
    }

    function test_cashKYCSenderReceiver_burnFrom() public {
        _mintCash(_getActor(), 1e18);
        cashKYCSenderReceiver_approve(_getActor(), 1e18); // approve self as spender
        cashKYCSenderReceiver_burnFrom(_getActor(), 5e17);
    }

    function test_cashKYCSenderReceiver_transfer() public {
        _mintCash(_getActor(), 1e18);
        cashKYCSenderReceiver_transfer(user, 5e17); // user is KYC'd
    }

    function test_cashKYCSenderReceiver_transferFrom() public {
        _mintCash(_getActor(), 1e18);
        cashKYCSenderReceiver_approve(_getActor(), 1e18);
        cashKYCSenderReceiver_transferFrom(_getActor(), user, 5e17);
    }

    function test_cashKYCSenderReceiver_approve() public {
        cashKYCSenderReceiver_approve(user, 1e18);
    }

    function test_cashKYCSenderReceiver_increaseAllowance() public {
        cashKYCSenderReceiver_increaseAllowance(user, 1e18);
    }

    function test_cashKYCSenderReceiver_decreaseAllowance() public {
        cashKYCSenderReceiver_approve(user, 1e18);
        cashKYCSenderReceiver_increaseAllowance(user, 1e18);
        cashKYCSenderReceiver_decreaseAllowance(user, 1e18);
    }

    function test_cashKYCSenderReceiver_pause_unpause() public {
        cashKYCSenderReceiver_pause();
        cashKYCSenderReceiver_unpause();
    }

    function test_cashKYCSenderReceiver_grantRole() public {
        cashKYCSenderReceiver_grantRole(cashKYCSenderReceiver.MINTER_ROLE(), user);
    }

    function test_cashKYCSenderReceiver_revokeRole() public {
        cashKYCSenderReceiver_grantRole(cashKYCSenderReceiver.MINTER_ROLE(), user);
        cashKYCSenderReceiver_revokeRole(cashKYCSenderReceiver.MINTER_ROLE(), user);
    }

    function test_cashKYCSenderReceiver_renounceRole() public {
        // asActor (address(this)) holds DEFAULT_ADMIN_ROLE; renounce a held role.
        cashKYCSenderReceiver_renounceRole(cashKYCSenderReceiver.MINTER_ROLE(), address(this));
    }

    function test_cashKYCSenderReceiver_setKYCRegistry() public {
        // Needs KYC_CONFIGURER_ROLE (not granted by initialize); grant first.
        cashKYCSenderReceiver_grantRole(cashKYCSenderReceiver.KYC_CONFIGURER_ROLE(), address(this));
        cashKYCSenderReceiver_setKYCRegistry(address(kYCRegistry));
    }

    function test_cashKYCSenderReceiver_setKYCRequirementGroup() public {
        cashKYCSenderReceiver_grantRole(cashKYCSenderReceiver.KYC_CONFIGURER_ROLE(), address(this));
        cashKYCSenderReceiver_setKYCRequirementGroup(KYC_GROUP);
    }

    /*//////////////////////////////////////////////////////////////
      LENDING DELEGATES (bare impls) - JUSTIFIED REVERTS
      The CCashDelegate / CTokenDelegate are deployed bare: admin == address(0)
      and no Comptroller / InterestRateModel / market wiring. Every state- and
      interest-touching handler therefore reverts (admin gate, or call into a
      zero InterestRateModel). Full market deployment is deferred to the COVERAGE
      phase. We assert the revert so the handler reachability is documented.
      See magic/reverting-handlers.json.
    //////////////////////////////////////////////////////////////*/

    function test_cCashDelegate_setKYCRegistry_reverts() public {
        vm.expectRevert(); // "Only admin can set KYC registry" (admin == 0)
        this.cCashDelegate_setKYCRegistry(address(kYCRegistry));
    }

    function test_cCashDelegate_setKYCRequirementGroup_reverts() public {
        vm.expectRevert();
        this.cCashDelegate_setKYCRequirementGroup(KYC_GROUP);
    }

    function test_cCashDelegate_mint_reverts() public {
        vm.expectRevert(); // interestRateModel == address(0) -> accrueInterest reverts
        this.cCashDelegate_mint(1e18);
    }

    function test_cCashDelegate_accrueInterest_reverts() public {
        vm.expectRevert();
        this.cCashDelegate_accrueInterest();
    }

    function test_cCashDelegate_exchangeRateCurrent_reverts() public {
        vm.expectRevert();
        this.cCashDelegate_exchangeRateCurrent();
    }

    function test_cCashDelegate_totalBorrowsCurrent_reverts() public {
        vm.expectRevert();
        this.cCashDelegate_totalBorrowsCurrent();
    }

    function test_cCashDelegate_approve_works() public {
        // approve does not touch the missing market wiring.
        cCashDelegate_approve(user, 1e18);
    }

    function test_cTokenDelegate_setKYCRegistry_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_setKYCRegistry(address(kYCRegistry));
    }

    function test_cTokenDelegate_setKYCRequirementGroup_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_setKYCRequirementGroup(KYC_GROUP);
    }

    function test_cTokenDelegate_mint_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_mint(1e18);
    }

    function test_cTokenDelegate_accrueInterest_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_accrueInterest();
    }

    function test_cTokenDelegate_exchangeRateCurrent_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_exchangeRateCurrent();
    }

    function test_cTokenDelegate_totalBorrowsCurrent_reverts() public {
        vm.expectRevert();
        this.cTokenDelegate_totalBorrowsCurrent();
    }

    function test_cTokenDelegate_approve_works() public {
        cTokenDelegate_approve(user, 1e18);
    }
}
