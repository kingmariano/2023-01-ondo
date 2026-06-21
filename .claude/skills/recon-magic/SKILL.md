---
name: recon-magic
description: >-
  Run the Recon Magic Framework's fuzzing & audit workflows natively inside Claude Code.
  Drives Foundry smart-contract repos through multi-phase pipelines: Recon/Chimera fuzzing-harness
  SETUP & scaffolding, COVERAGE improvement (clamped/shortcut handlers), invariant/PROPERTY
  generation, contract SCOUTING/classification, UNIT-test generation, and naive AUDITs — plus raw
  echidna/medusa fuzz runs. Use when the user mentions recon-magic, recon magic framework, recon
  fuzzing setup, Chimera harness, scaffolding a fuzz suite, echidna/medusa coverage, writing
  invariants/properties for a protocol, or "run the X workflow". Claude itself executes the
  workflow engine (no external Python orchestrator needed).
---

# Recon Magic — Fuzzing & Audit Workflows

This skill is a self-contained port of [`Recon-Fuzz/recon-magic-framework`](https://github.com/Recon-Fuzz/recon-magic-framework).
Upstream, a Python engine (`main.py`) reads a JSON **workflow** and drives `claude -p` / `opencode`
through its phases. **Here, *you* (Claude Code) are that engine.** You read the same workflow JSON and
the same agent prompts (vendored under `framework/`) and execute the steps yourself — dispatching agent
phases via the Task tool, running `PROGRAM` steps via Bash, and evaluating decision gates directly.

> **Scope**: these workflows operate on a **Foundry smart-contract repo** (the *target*). Setup/coverage/
> properties/scouting/unit are for fuzzing engagements; `audit` is a lightweight bug-hunt. They modify the
> target repo (scaffolding, handlers, properties, tests). Run from the target repo's root.

---

## 0. Quickstart

1. **Confirm the target.** These workflows act on the repo in the current working directory (or a path the
   user gives). It must be a Foundry project (has, or can be migrated to, `foundry.toml`).
2. **Run preflight once** (installs the CLI tools the PROGRAM steps call):
   ```bash
   bash ~/.claude/skills/recon-magic/scripts/preflight.sh
   ```
3. **Pick a workflow** from the dispatcher below based on what the user wants.
4. **Execute it** following the engine in `reference/engine.md`. Announce the workflow + ordered phases
   first, then run step by step, reporting each step's result.

The skill root is `~/.claude/skills/recon-magic/`. Everything under `framework/` is the vendored upstream with some folders removed for better modularity.
project: `framework/workflows/*.json`, `framework/prompts/agent/*.md`, `framework/tools/`.

---

## 1. Workflow dispatcher

Map the user's intent to an **entry workflow** file in `framework/workflows/`. When unsure which the user
wants, ask; don't guess between setup and coverage. The standard end-to-end order is
**scouting → setup → coverage → properties** (each consumes the previous one's artifacts).

| User wants… | Entry workflow | What it does |
|---|---|---|
| Discover/classify contracts, plan scaffolding | `workflow-fuzzing-scouting-v2.json` | Contract discovery → scaffolding spec → deep parameter analysis (writes `magic/*.json`) |
| Build the fuzzing harness / scaffold a Recon suite | `workflow-fuzzing-setup-v2.json` | Foundry migration → `recon-generate` scaffolding → `Setup.sol` → mocks → targets → admin split → unit tests → echidna validation |
| Improve fuzzing coverage | `workflow-fuzzing-coverage.json` | Target extraction → clamped & shortcut handlers → echidna → coverage eval → iterate on gaps |
| Generate invariants / properties | `workflow-properties-efficient-v4.0-claude.json` | Reachability/taint analysis → tiered property identification → implementation → smoke test vs fuzzer |
| Generate unit tests for handlers | compose `unit-phase-*` (`framework/prompts/agent/unit-phase-{0..4}.md`) | Per-handler unit tests validating setup |
| Lightweight naive audit | `audit.json` | Scoping → issue generation (with a CRITICAL_STOP gate) |
| Just compile-fix + fuzz | `workflow-compile-and-fuzz.json` | Fix compilation, then run echidna |
| Just run the fuzzer | `workflow-fuzz-only.json` / `workflow-echidna-example.json` | Echidna run only |

**Other useful entries** (see `reference/catalog.md` for the full list of 32 workflows):
`workflow-fuzzing-setup.json` (v1), `workflow-properties-full.json` / `-full-opus.json`,
`workflow-fuzzing-scouting.json` (v1), and the `compose-*.json` meta-workflows that chain
setup→coverage→properties via `workflow`-type composition.

Older/alternate variants (`*-v2`, `*-efficient-v4.0`, `*-full-opus`) exist; **prefer the v2 / v4 / claude
variants** unless the user asks otherwise.

---

## 2. The engine (how to run a workflow)

Full semantics are in **`reference/engine.md`** — read it before executing. Summary:

**Setup (once per run):**
- `RECON_FOUNDRY_ROOT` = the directory containing `foundry.toml` (auto-detect; for a monorepo it may be a
  subdir). Fall back to the repo root. **All `PROGRAM` steps run with `cwd = RECON_FOUNDRY_ROOT`.**
- `PROMPTS_DIR` = `~/.claude/skills/recon-magic/framework/prompts` (used to resolve agent-file references
  and `${PROMPTS_DIR}/...` mentions inside prompts).
- Load the chosen workflow JSON. If any step has `"type": "workflow"`, **flatten** it by inlining the
  referenced workflow's steps in place (recursively).

**Then iterate steps in order:**

- **`task` + `PROGRAM`** → run `prompt` as a shell command via Bash at `RECON_FOUNDRY_ROOT`. If
  `output.capture` is true, write stdout to `output.save_to` (replace `{timestamp}` with a UTC stamp). If
  `allowFailure` is true, a non-zero exit does not stop the workflow.
- **`task` + `CLAUDE_CODE` / `OPENCODE`** → the `prompt` usually says *"agent definition at
  `./prompts/agent/<name>.md`… Run exclusively the `<name>` agent using the Task tool."* Resolve and **read**
  `framework/prompts/agent/<name>.md`, strip its YAML frontmatter, and **dispatch the body as a
  `general-purpose` subagent via the Task tool** so each phase gets fresh context (this mirrors upstream's
  fresh `claude -p` per phase). If the `prompt` is a plain instruction with no agent reference, run it
  directly. Pass along that the subagent works in the target repo at `RECON_FOUNDRY_ROOT`.
- **`decision`** → evaluate the gate per its `mode` (FILE_EXISTS, FILE_CONTAINS, READ_FILE, JSON_KEY_VALUE,
  GREP, SHELL, USE_MODEL, READ_FILE_WITH_MODEL_DIGEST — see `reference/engine.md`), then apply the matching
  `decision[].action`: `CONTINUE` (default), `STOP`, `JUMP_TO_STEP` (to `destinationStep`), or
  `REPEAT_PREVIOUS_STEP`. **Loop hardcap = 5**: if a decision step has already executed 5 times, force
  `CONTINUE` to prevent infinite loops.
- **`preconditions`** (a step field) → named gates defined in `framework/workflows/workflow-gates.json`;
  evaluate the gate before running the step.
- **`DISPATCH_FUZZING_JOB`** → upstream this hands off to Recon Pro cloud fuzzing. Locally, treat it as
  "run the fuzzer" — run echidna/medusa per the job config, or note it as a manual/cloud handoff and stop.

**Sentinel files** drive the gates: phases write files like `CRITICAL_STOP.md`, `COMPILATION_FAILED.md`,
`COMPILATION_SUCCESS.md`, or `magic/functions-missing-covg-*.json`, and decision steps branch on them.

---

## 3. Commit policy (opt-in, default OFF)

Upstream commits after most steps for state tracking/rollback. **This skill does not auto-commit by
default.** Only if the user explicitly asks (e.g. says "commit" / "commit each step") should you `git add`
+ `git commit` after steps whose JSON has `"shouldCommitChanges": true`, using the step name as the message.
**Never push.** Without that opt-in, leave git untouched and let the user review the diff.

---

## 4. Safety rules (from upstream `AI Orchestration.md`)

- **Fill slots, don't invent commands.** Run `PROGRAM` step commands as written (substituting only env vars
  like `${RECON_FOUNDRY_ROOT}`). Don't replace a step's command with an improvised one; if a command fails,
  fix the underlying cause or report it — don't rewrite the pipeline.
- **No path traversal / no destructive surprises.** These workflows scaffold and edit the *target* repo;
  surface anything that would delete or overwrite non-generated source before doing it.
- **Respect the loop hardcap** (5) and report when a gate forces an exit.
- Heavy steps (echidna/medusa) can run long; use generous Bash timeouts and stream/tee output to a file as
  the workflow specifies.

---

## 5. Reference docs

- **`reference/engine.md`** — full step/decision schema, all 8 gate modes, actions, output capture,
  composition flattening, loop protection. *Read this before executing a workflow.*
- **`reference/catalog.md`** — every workflow family: entry file, ordered phases, the `magic/` artifact
  flow, and "use when".
- **`reference/tools.md`** — the 11 bundled CLI tools, external dependencies, and the `magic/*.json` file
  formats.
- **`README.md`** — overview, the Claude-as-engine work-around, attribution (Recon-Fuzz, GPL-2.0).
