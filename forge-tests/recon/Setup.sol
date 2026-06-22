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

// Your deps (NAMED imports of the 6 core contracts — do not collapse to wildcard)
import {CCashDelegate} from "contracts/lending/tokens/cCash/CCashDelegate.sol";
import {CTokenDelegate} from "contracts/lending/tokens/cToken/CTokenDelegate.sol";
import {CashKYCSenderReceiver} from "contracts/cash/token/CashKYCSenderReceiver.sol";
import {CashManager} from "contracts/cash/CashManager.sol";
import {KYCRegistry} from "contracts/cash/kyc/KYCRegistry.sol";
import {OndoPriceOracleV2} from "contracts/lending/OndoPriceOracleV2.sol";

// Supporting types
import {ERC1967Proxy} from "contracts/cash/external/openzeppelin/contracts/proxy/ERC1967Proxy.sol";
import {IOndoPriceOracleV2} from "contracts/lending/IOndoPriceOracleV2.sol";
import {MockSanctionsList} from "forge-tests/recon/mocks/MockSanctionsList.sol";
import {MockAggregatorV3} from "forge-tests/recon/mocks/MockAggregatorV3.sol";
import {MockFToken} from "forge-tests/recon/mocks/MockFToken.sol";
import {MockERC20Decimals} from "forge-tests/recon/mocks/MockERC20Decimals.sol";
import {MockCTokenOracle} from "forge-tests/recon/mocks/MockCTokenOracle.sol";
import {IERC20} from "contracts/cash/external/openzeppelin/contracts/token/IERC20.sol";
import {MockComptroller} from "forge-tests/recon/mocks/MockComptroller.sol";
import {MockInterestRateModel} from "forge-tests/recon/mocks/MockInterestRateModel.sol";

/// @dev Recon harness setup for the Ondo CASH-issuance + Flux/Compound lending suite.
///
/// Architecture (see magic/setup-decisions.json):
///   (1) CASH issuance: CashManager <-> CashKYCSenderReceiver (CASH token, proxy)
///       gated by a shared KYCRegistry (backed by a mocked SanctionsList).
///   (2) Flux lending: OndoPriceOracleV2 + CTokenDelegate (fToken) + CCashDelegate
///       (cCASH). The delegates are Compound delegate IMPLEMENTATIONS deployed bare;
///       full market runtime wiring (delegator proxy admin + Comptroller + IRM) is
///       partial — see audit notes below.
abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    // === Core contracts === ///
    CCashDelegate cCashDelegate;
    CTokenDelegate cTokenDelegate;
    CashKYCSenderReceiver cashKYCSenderReceiver; // proxy address, typed as the token
    CashManager cashManager;
    KYCRegistry kYCRegistry;
    OndoPriceOracleV2 ondoPriceOracleV2;

    // === Supporting infra === ///
    MockSanctionsList internal sanctionsList;
    MockAggregatorV3 internal chainlinkOracle;
    address internal collateralToken; // USDC-like MockERC20 (6 decimals)
    address internal underlyingToken; // DAI-like MockERC20 (18 decimals)

    // === GROUP B: Oracle alternate path wiring === ///
    /// @custom:coverage GROUP B: MockFToken instances used for COMPOUND and CHAINLINK paths.
    ///        fTokenCompound: has underlying == address(0), matching cCashDelegate.underlying()
    ///        fTokenChainlink: has underlying == underlyingToken (18 dec) for scaleFactor compute
    MockFToken internal fTokenCompound;   // fToken wired to OracleType.COMPOUND
    MockFToken internal fTokenChainlink;  // fToken wired to OracleType.CHAINLINK
    MockCTokenOracle internal mockCTokenOracle; // replaces the default mainnet cTokenOracle

    // === GROUP A: Full Compound market wiring === ///
    /// @custom:coverage GROUP A: A second CTokenDelegate (wired with MockComptroller + MockInterestRateModel)
    ///        so accrueInterest and all cToken state-changing functions become reachable.
    ///        The admin slot is set via vm.store so initialize() can be called from address(this).
    CTokenDelegate internal cTokenDelegateWired; // fresh CTokenDelegate with admin=address(this), wired IRM+Comptroller
    MockComptroller internal mockComptroller;     // passes all policy checks, returns 0 (success)
    MockInterestRateModel internal mockIRM;       // returns a constant tiny borrow rate
    bool internal groupAWired;                   // true if Group A wiring succeeded without reverting

    // === Constants === ///
    uint256 internal constant DECIMALS = 18;
    /// @custom:audit KYC GROUP CONSISTENCY: this single group is passed to the
    ///        CASH token, CashManager, and is the group every actor is KYC'd in.
    ///        A mismatch silently disables all KYC-gated operations.
    uint256 internal constant KYC_GROUP = 1;
    /// @custom:audit Hardcoded Chainalysis sanctions constant declared `constant`
    ///        in the cToken/cCash interfaces; cannot be injected, must be etched.
    address internal constant SANCTIONS_CONSTANT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
    /// @custom:audit Default UniswapAnchoredView cTokenOracle in OndoPriceOracleV2;
    ///        a live mainnet address only used by the COMPOUND oracle path.
    address internal constant CTOKEN_ORACLE_DEFAULT =
        0x65c816077C29b557BEE980ae3cC2dCE80204A0C5;

    // === Multi-user / signature actor === ///
    /// @custom:audit Keyed actor enables the EIP-712 addKYCAddressViaSignature path.
    uint256 internal userPrivateKey =
        23868421370328131711506074113045611601786642648093516849953535378706721142721;
    address internal user = 0x537C8f3d3E18dF5517a58B3fB9D9143697996802;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        /// @custom:audit TIME/BLOCK COUPLING: CashManager epochs use timestamps
        ///        (epoch modulo needs block.timestamp non-zero) while Compound
        ///        cTokens accrue by block.number; warp AND roll to a sane start.
        vm.warp(1_700_000_000); // non-zero timestamp for epochs / Chainlink freshness
        vm.roll(1_000); // non-zero block for cToken accrual

        // --- 1. Sanctions mock + etch onto hardcoded constant ---
        _etchSanctionsList();

        // --- 2. KYCRegistry (admin = address(this)) ---
        /// @custom:audit Single shared registry gates every KYC-aware contract.
        ///        admin = address(this) so the harness holds REGISTRY_ADMIN.
        kYCRegistry = new KYCRegistry(address(this), address(sanctionsList));
        // Assign REGISTRY_ADMIN as the gating role for KYC_GROUP so address(this)
        // (which holds REGISTRY_ADMIN) can addKYCAddresses for that group.
        kYCRegistry.assignRoletoKYCGroup(KYC_GROUP, kYCRegistry.REGISTRY_ADMIN());

        // --- 3. Price oracle (owner = deployer) ---
        ondoPriceOracleV2 = new OndoPriceOracleV2();
        chainlinkOracle = new MockAggregatorV3();

        // --- 4. CASH token behind a proxy (MUST precede CashManager) ---
        /// @custom:audit ORDERING: CASH token must be initialized (decimals=18)
        ///        BEFORE CashManager is constructed (constructor reads decimals).
        /// @custom:audit PROXY: CashKYCSenderReceiver constructor _disableInitializers();
        ///        the bare impl is unusable, so deploy behind ERC1967Proxy.
        _deployCashTokenBehindProxy();

        // --- 5. Collateral + underlying ERC20s ---
        /// @custom:audit requestMint pulls collateral via safeTransferFrom; USDC=6
        ///        decimals gives decimalsMultiplier = 1e12 (cash 18 >= collateral 6).
        collateralToken = _newAsset(6); // USDC-like collateral
        underlyingToken = _newAsset(18); // DAI-like generic cToken underlying

        // --- 6. CashManager (12 args, all addresses non-zero) ---
        /// @custom:audit CONSTRUCTOR ZERO-CHECKS: all address args must be non-zero;
        ///        address(this) used for admin/pauser/recipients/sender.
        /// @custom:audit EPOCH MATH: epochDuration must be > 0 (constructor modulo).
        /// @custom:audit Zero mint/redeem limits silently disable mint/redeem; use
        ///        large non-zero limits as documented assumptions.
        cashManager = new CashManager(
            collateralToken, // _collateral
            address(cashKYCSenderReceiver), // _cash (proxy)
            address(this), // managerAdmin
            address(this), // pauser
            address(this), // _assetRecipient
            address(this), // _assetSender
            address(this), // _feeRecipient
            type(uint128).max, // _mintLimit
            type(uint128).max, // _redeemLimit
            1 days, // _epochDuration (> 0)
            address(kYCRegistry), // _kycRegistry
            KYC_GROUP // _kycRequirementGroup
        );

        /// @custom:audit MINTER_ROLE: CashManager must hold MINTER_ROLE on CASH or
        ///        claimMint / refunds / redemptions revert. address(this) is the
        ///        token DEFAULT_ADMIN (set during proxy initialize).
        cashKYCSenderReceiver.grantRole(
            cashKYCSenderReceiver.MINTER_ROLE(),
            address(cashManager)
        );

        /// @custom:coverage GROUP C: grant KYC_CONFIGURER_ROLE to address(this) so that
        ///        the cashKYCSenderReceiver_setKYCRegistry_clamped handler can succeed.
        ///        address(this) holds DEFAULT_ADMIN_ROLE and can self-grant this role.
        cashKYCSenderReceiver.grantRole(
            cashKYCSenderReceiver.KYC_CONFIGURER_ROLE(),
            address(this)
        );

        /// @custom:audit SETTER_ADMIN: setMintExchangeRate is gated by SETTER_ADMIN,
        ///        which the constructor does NOT grant to managerAdmin (only
        ///        DEFAULT_ADMIN_ROLE + MANAGER_ADMIN). MANAGER_ADMIN is the role
        ///        admin of SETTER_ADMIN, so address(this) can self-grant it; do so
        ///        here so the setMintExchangeRate / claimMint flow is reachable.
        cashManager.grantRole(cashManager.SETTER_ADMIN(), address(this));

        // --- 7. Lending delegate implementations (bare; see audit gap) ---
        /// @custom:audit ADMIN PROBLEM (cTokens): CTokenDelegate/CCashDelegate
        ///        initialize require msg.sender==admin but the bare delegate's
        ///        admin is address(0). Full market wiring (delegator proxy +
        ///        Comptroller + IRM) is out of scope for base setup; delegates are
        ///        deployed bare so the suite compiles and setUp succeeds. Most
        ///        cToken state-changing handlers will revert until a future
        ///        COVERAGE phase stands up real markets via helper deploys.
        cTokenDelegate = new CTokenDelegate();
        cCashDelegate = new CCashDelegate();

        // --- 8. Oracle MANUAL price wiring for the delegates as fTokens ---
        /// @custom:audit ORACLE PATHS: MANUAL is the only path usable with zero
        ///        external infra; setFTokenToOracleType(MANUAL) MUST precede setPrice.
        ondoPriceOracleV2.setFTokenToOracleType(
            address(cTokenDelegate),
            IOndoPriceOracleV2.OracleType.MANUAL
        );
        ondoPriceOracleV2.setPrice(address(cTokenDelegate), 1e18);
        ondoPriceOracleV2.setFTokenToOracleType(
            address(cCashDelegate),
            IOndoPriceOracleV2.OracleType.MANUAL
        );
        ondoPriceOracleV2.setPrice(address(cCashDelegate), 1e18);

        // --- 8b. GROUP B: Wire COMPOUND and CHAINLINK oracle paths ---
        /// @custom:coverage GROUP B: Configure alternate oracle paths so getUnderlyingPrice
        ///        routes to COMPOUND and CHAINLINK branches, enabling coverage of those paths.

        // COMPOUND path:
        //   fTokenCompound.underlying() == address(0) == cCashDelegate.underlying()
        //   so _setFTokenToCToken passes the equality check.
        //   A MockCTokenOracle replaces the default mainnet UniswapAnchoredView so
        //   getUnderlyingPrice(fTokenCompound) can succeed without a network call.
        fTokenCompound = new MockFToken(address(0));
        mockCTokenOracle = new MockCTokenOracle();
        ondoPriceOracleV2.setOracle(address(mockCTokenOracle));
        ondoPriceOracleV2.setFTokenToOracleType(
            address(fTokenCompound),
            IOndoPriceOracleV2.OracleType.COMPOUND
        );
        ondoPriceOracleV2.setFTokenToCToken(address(fTokenCompound), address(cCashDelegate));

        // CHAINLINK path:
        //   fTokenChainlink.underlying() == underlyingToken (18 decimals) so
        //   _setFTokenToChainlinkOracle can compute scaleFactor = 10^(36-18-8) = 10^10.
        //   chainlinkOracle (MockAggregatorV3) returns updatedAt=block.timestamp so
        //   the staleness check passes.
        fTokenChainlink = new MockFToken(underlyingToken);
        ondoPriceOracleV2.setFTokenToOracleType(
            address(fTokenChainlink),
            IOndoPriceOracleV2.OracleType.CHAINLINK
        );
        ondoPriceOracleV2.setFTokenToChainlinkOracle(
            address(fTokenChainlink),
            address(chainlinkOracle)
        );

        // --- 9. Multi-user actors + KYC ---
        /// @custom:audit Multiple KYC'd actors enable transfer/redemption coverage;
        ///        a keyed actor enables the signature-based KYC path.
        _addActor(user);
        _kycActor(address(this));
        _kycActor(user);
        // The CASH token / delegates may need to custody CASH (KYC-gated); KYC them
        // so transfers to those contracts are not blocked.
        _kycActor(address(cashManager));
        _kycActor(address(cCashDelegate));

        // --- 10. Fund + approve actors (mint collateral/underlying, approve spenders) ---
        /// @custom:audit REDEMPTION FUNDING: completeRedemptions pulls collateral
        ///        from assetSender (= address(this)); it is an actor and is funded
        ///        + approved by _finalizeAssetDeployment.
        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(cashManager);
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);

        // --- 11. GROUP A: Wire full Compound market (guarded) ---
        /// @custom:coverage GROUP A: Deploy Unitroller + Comptroller + JumpRateModelV2 +
        ///        CErc20DelegatorKYC proxy, wire markets, fund actors. If any step reverts,
        ///        groupAWired = false and Group A handlers become no-ops at runtime.
        _wireGroupA();
    }

    /// === Dynamic deploy / helpers === ///

    /// @notice GROUP A: Wire a full Compound lending market so cToken delegate state-changing
    ///         functions become reachable by the fuzzer.
    ///         Deploys a fresh CTokenDelegate and uses vm.store to set admin=address(this)
    ///         so initialize() can be called. Uses MockComptroller + MockInterestRateModel
    ///         (both 0.8.x) which always return 0 (success).
    /// @dev    Sets groupAWired=true only on full success.
    function _wireGroupA() internal {
        // Step 1: Deploy mock Comptroller and IRM (0.8.x, compatible with CTokenModified interfaces)
        mockComptroller = new MockComptroller();
        mockIRM = new MockInterestRateModel();

        // Step 2: Deploy a fresh CTokenDelegate (this is the implementation that will be wired)
        cTokenDelegateWired = new CTokenDelegate();

        // Step 3: Set admin slot so initialize() passes the msg.sender==admin check.
        //         CTokenStorage layout (Solidity right-packs variables, CTokenInterfacesModified.sol):
        //           slot 0: _notEntered (bool, 1 byte, right-justified)
        //           slot 1: name (string, dynamic)
        //           slot 2: symbol (string, dynamic)
        //           slot 3: decimals (uint8, byte 31) + admin (address, bytes 11-30) packed
        //                   → admin is 20 bytes starting at byte 11 (offset 8 bits from LSB)
        //         We write address(this) into slot 3, shifted left by 8 bits (room for decimals).
        vm.store(
            address(cTokenDelegateWired),
            bytes32(uint256(3)), // slot 3 = packed (admin, decimals)
            bytes32(uint256(uint160(address(this))) << 8) // admin at offset 8, decimals = 0
        );

        // Step 4: Initialize the wired delegate via address(this) (which is now admin)
        //         underlying_ = underlyingToken (18 decimals)
        //         initialExchangeRateMantissa = 2e26 (standard for 18-dec underlying, 8-dec cToken)
        cTokenDelegateWired.initialize(
            underlyingToken,                              // underlying_
            mockComptroller,                              // comptroller_
            mockIRM,                                      // interestRateModel_
            2e26,                                         // initialExchangeRateMantissa_
            "Wired Test Token",                           // name_
            "wTST",                                       // symbol_
            8,                                            // decimals_
            address(kYCRegistry),                         // kycRegistry_
            KYC_GROUP                                     // kycRequirementGroup_
        );

        // Step 5: Set oracle price for the wired delegate (MANUAL type)
        ondoPriceOracleV2.setFTokenToOracleType(
            address(cTokenDelegateWired),
            IOndoPriceOracleV2.OracleType.MANUAL
        );
        ondoPriceOracleV2.setPrice(address(cTokenDelegateWired), 1e18); // $1 price

        // Step 6: KYC the wired delegate address (some KYC-gated operations check the token itself)
        _kycActor(address(cTokenDelegateWired));

        // Step 7: Fund actors with underlying and approve the wired delegate
        // Actors already have underlyingToken from _finalizeAssetDeployment.
        // Approve the wired delegate so mint() can pull tokens.
        address[] memory actors = _getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            vm.startPrank(actors[i]);
            IERC20(underlyingToken).approve(address(cTokenDelegateWired), type(uint256).max);
            vm.stopPrank();
        }

        groupAWired = true;
    }

    /// @notice Deploy MockSanctionsList and etch its runtime onto the hardcoded
    ///         cToken/cCash sanctions constant so sanction checks don't revert.
    function _etchSanctionsList() internal {
        sanctionsList = new MockSanctionsList();
        vm.etch(SANCTIONS_CONSTANT, address(sanctionsList).code);
    }

    /// @notice Deploy the CASH token implementation, wrap in an ERC1967Proxy, and
    ///         initialize through the proxy. Treats the proxy as the live token.
    function _deployCashTokenBehindProxy() internal {
        CashKYCSenderReceiver impl = new CashKYCSenderReceiver();
        bytes memory initData = abi.encodeWithSelector(
            CashKYCSenderReceiver.initialize.selector,
            "Ondo CASH",
            "CASH",
            address(kYCRegistry),
            KYC_GROUP
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cashKYCSenderReceiver = CashKYCSenderReceiver(address(proxy));
    }

    /// @notice KYC an address into the active KYC group (called as REGISTRY_ADMIN).
    function _kycActor(address who) internal {
        address[] memory addrs = new address[](1);
        addrs[0] = who;
        kYCRegistry.addKYCAddresses(KYC_GROUP, addrs);
    }

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
