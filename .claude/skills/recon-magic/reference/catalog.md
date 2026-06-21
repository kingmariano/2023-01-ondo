# Workflow Catalog

All workflows live in `framework/workflows/` (32 files). Agent phases live in
`framework/prompts/agent/`. This catalog covers the families you'll actually run; prefer the **v2 / v4 /
claude** variants. The canonical engagement order is **Scouting → Setup → Coverage → Properties**, each
consuming the previous step's `magic/*.json` artifacts.

Reference docs that agent phases read (resolve via `${PROMPTS_DIR}` = `framework/prompts/`):
`styleguide.md` (echidna config + fixes), `clamping-handler-rules.md`, `invariant-workshop.md`,
`objective-coverage.md`, `audit-template.md`, `templates/scope.md`.

Shared gates (`workflow-gates.json`): `forge-build-gate`, `smoke-test-gate`, `echidna-run-gate`.

---

## Scouting — plan what to scaffold
**Entry:** `workflow-fuzzing-scouting-v2.json` (7 steps). **Use when:** starting a new fuzzing engagement;
decide which contracts to target/mock and what setup needs.
- Phase 0 `scout-v2-phase-0` — contract discovery & classification → writes a classification JSON
- *(gate: Validate Classification File)*
- Phase 1 `scout-v2-phase-1` — generate scaffolding spec → `magic/contracts-to-scaffold.json`
- *(gate: Validate Scaffolding Spec File)*
- Phase 2 `scout-v2-phase-2` — deep parameter analysis → `magic/setup-config-spec.json`
- *(gate: Validate Setup Config Spec)* → Complete

v1 alternative: `workflow-fuzzing-scouting.json` (`scouting-phase-0..2`, plus `scouting-alternative*`).

---

## Setup — build the Recon/Chimera harness
**Entry:** `workflow-fuzzing-setup-v2.json` (~22 steps). **Use when:** you have a scaffolding spec and want a
compiling, echidna-validated fuzz suite. Phases (`setup-v2-phase-*`) interleaved with PROGRAM steps:
- Phase 0 `setup-v2-phase-0` — Foundry migration (Hardhat→Foundry if needed), ensure `forge build`
- *(gate: `COMPILATION_FAILED.md` → STOP)*
- PROGRAM: install deps, suppress lint, validate mock names, build to `.recon/out`, run
  `npx recon-generate@latest` scaffolding, clean flattened imports
- Phase 1 `setup-v2-phase-1` — install chimera, create remaining mocks, verify compile
- Phase 2 `setup-v2-phase-2` — implement `Setup.sol` from `magic/setup-config-spec.json`
- Fix Import Collisions *(inline agent step — no agent file)*
- Phase 3 `setup-v2-phase-3` — validate with `forge build` / `forge test` / echidna
- PROGRAM: auto-link libraries (`recon-generate link2`), `extract-target-functions` →
  `magic/target-functions.json`
- Phase 5 `setup-v2-phase-5` — identify prerequisite functions → `magic/function-sequences.json`
- PROGRAM: `order-prerequisite-func` → `magic/function-sequences-sorted.json`
- Phase 6 `setup-v2-phase-6` — move admin functions to `AdminTargets`
- Phase 7 `setup-v2-phase-7` — write unit tests for handlers
- PROGRAM: final echidna validation → writes `FUZZING_SETUP_COMPLETE.md`

v1 alternative: `workflow-fuzzing-setup.json` (`setup-phase-0a/0b/1/2/3`). Partial:
`workflow-properties-partial-from-setup.json`.

---

## Coverage — close fuzzing coverage gaps
**Entry:** `workflow-fuzzing-coverage.json` (47 steps; short version `workflow-fuzzing-coverage-short.json`).
**Use when:** the suite compiles & runs but coverage is low. Two big loops with echidna-retry and
compilation-retry counters guarding each. Key steps:
- `extract-target-functions` → build `--build-info` → `filter-build-info` → `sol-expand --extract-context`
  *(gate: retry context on failure)*
- `coverage-phase-1` identify meaningful clamp values → `coverage-phase-2` clamped handlers → generate
  non-reverting paths → `coverage-phase-3`-style sequences → `merge-paths-prerequisites` → shortcut handlers
- Run echidna → `analyze-echidna-output` *(gate: handle results; on errors → fix-echidna / fix-compilation
  with retry-limit counters)*
- `covg-eval` → `covg-scoring` (score & sort by complexity) → `get-latest-coverage` link
- *(gate: `functions-missing-covg-*.json` exists?)* → if gaps: group/prioritize, analyze gaps,
  `coverage-phase-5` implement solutions, re-run echidna, re-eval, `update-coverage-groups`, loop
- terminal: `DISPATCH_FUZZING_JOB` (cloud fuzz handoff) → Complete

Handler rules: `clamping-handler-rules.md`; coverage tooling: `objective-coverage.md`.

---

## Properties — generate & implement invariants
**Entry:** `workflow-properties-efficient-v4.0-claude.json` (26 steps; non-claude variant
`workflow-properties-efficient-v4.0.json`). **Use when:** the harness is set up and you want invariant
properties wired and smoke-tested. CLAUDE_CODE phases each followed by many validation-gate decisions:
- Phase 0 `properties-v4-phase-0` — dependency + reachability + wiring + taint + liveness analysis
  *(10 validation gates: dependency list, review priority, reachability, setup wiring, economic oracles,
  taint, function transitions, protocol-type detection, ghost infrastructure)*
- Phase 1A `properties-v4-phase-1a` — tiered property identification (tiers 0–10)
- Phase 1B `properties-v4-phase-1b` — low-priority tiers + free-form discovery
- Phase 2 `properties-v4-phase-2` — review, ghost classification, stale-op analysis, FP patterns
- *(gate: Check Recon Setup Exists)*
- Phase 3A `properties-v4-phase-3a` — wiring + infra + ProfitTracker + handler templates + SIMPLE/CANARY impl
- Phase 3B `properties-v4-phase-3b` — INLINE + NEGATIVE + DOOM implementation
- Smoke Test — validate properties against the fuzzer

Older full variants: `workflow-properties-full.json`, `workflow-properties-full-opus.json`
(`properties-phase-0..3`). Property design guide: `invariant-workshop.md`.

---

## Unit tests
**Compose** `unit-phase-0..4` (`framework/prompts/agent/unit-phase-{0..4}.md`). **Use when:** validating a
setup by exercising each handler in a deterministic unit test. (Run as agent phases in order; no dedicated
top-level `workflow-unit.json` — drive the phases directly or via the setup-v2 Phase 7 step.)

---

## Audit — lightweight naive bug hunt
**Entry:** `audit.json` (scoping + critical-stop gate + issue generation). Full phase set:
`audit-naive-phase-0..6` (and `first-audit-phase-0..5`, `pre-audit-phase-0..11` for deeper variants).
**Use when:** a quick automated pass for issues, independent of fuzzing. Phase 0 writes `CRITICAL_STOP.md`
to halt early on a blocker. Bug-report format: `audit-template.md`. **Note:** this is a naive single-model
pass — not a substitute for the `krait` / `plamen` audit pipelines.

---

## Raw fuzz / utility workflows
- `workflow-compile-and-fuzz.json` — fix compilation, then run echidna (2 steps).
- `workflow-fuzz-only.json` / `workflow-echidna-example.json` — echidna run only.
- `workflow-compile-and-fuzz` + `fix-compilation-errors` / `fix-echidna-failures` /
  `compilation-debugging-agent` / `chimera-test-linter` — debugging helpers.
- `generate-failure-report` — summarize echidna failures.

## Compose (meta) workflows — chain families via `workflow`-type composition
- `compose-scout-setup-v2.json` — Scout V2 → Setup V2
- `compose-setup-coverage.json` — Setup → Coverage
- `compose-coverage-properties.json` — Properties → Coverage
- `compose-scout-setup-coverage.json` — Scout → Setup → Coverage
- `compose-scout-setup-properties-coverage.json` — full Scout → Setup → Properties → Coverage
- `compose-setup-properties-coverage.json`, `compose-scout-setup-properties-coverage.json`

Flatten these (inline each referenced workflow's steps) before executing — see `engine.md` §5.

---

## `magic/` artifact flow (the data passed between phases)
```
scouting  → magic/contracts-to-scaffold.json, magic/setup-config-spec.json
setup     → magic/target-functions.json, magic/function-sequences.json,
            magic/function-sequences-sorted.json, admin-functions.json, FUZZING_SETUP_COMPLETE.md
coverage  → magic/functions-to-cover.json, magic/functions-missing-covg-{timestamp}.json,
            context_output/, echidna/ corpus & coverage
```
See `reference/tools.md` for the exact JSON shapes and which tool produces each.
