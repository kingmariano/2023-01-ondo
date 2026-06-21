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
