# Workflow Engine — execution model for Claude-as-orchestrator

This is the port of the upstream Python engine (`framework/main.py`, `framework/core/task.py`,
`framework/core/decision.py`) into instructions you execute directly. A **workflow** is a JSON object
`{ "name": str, "description"?: str, "steps": [ ... ] }`. Run its steps top-to-bottom, honoring decisions,
gates, and the loop hardcap.

---

## 0. Environment setup (once per run)

| Variable | Value | Used for |
|---|---|---|
| `RECON_FOUNDRY_ROOT` | directory containing `foundry.toml` (auto-detect; may be a subdir in a monorepo). Fallback: repo root. | **`cwd` for every `PROGRAM` step**, base path for gates, `cd` target for agent phases |
| `RECON_REPO_PATH` | target repo root | fallback base path |
| `PROMPTS_DIR` | `~/.claude/skills/recon-magic/framework/prompts` | resolving agent files + `${PROMPTS_DIR}/…` references inside prompts |

Base path for decision-gate file lookups = `RECON_FOUNDRY_ROOT` → else `RECON_REPO_PATH` → else cwd
(upstream `core/path_utils.get_base_path`). Foundry-root auto-detection: `find` for `foundry.toml`, skipping
`.git`, `node_modules`, `lib`; exactly one match → use it; none → repo root (or migrate during setup);
several → ask the user which.

---

## 1. Step shape

Every step has `type` (`task` | `decision` | `workflow`) and `name`. Common optional fields on `task` steps:

| Field | Meaning |
|---|---|
| `model.type` | `PROGRAM` \| `CLAUDE_CODE` \| `OPENCODE` \| `DISPATCH_FUZZING_JOB` (`model.model` is usually `"inherit"`) |
| `prompt` | shell command (PROGRAM) or agent instruction (CLAUDE_CODE/OPENCODE) |
| `allowFailure` | if true, a non-zero exit / failure does **not** stop the workflow |
| `output.capture` + `output.save_to` | capture stdout (PROGRAM) or the agent's response (LLM) and write it to `save_to`; replace `{timestamp}` with a UTC stamp (e.g. `date -u +%Y%m%dT%H%M%SZ`) |
| `preconditions` | list of named gates (see §4) evaluated before the step runs |
| `shouldCommitChanges` | upstream auto-commit flag — **honored only with the user's opt-in** (see SKILL.md §3) |
| `shouldCreateSummary` | upstream summary flag — informational; no action required |
| `staleTimeout` | upstream watchdog seconds for a stalled agent; locally just use a generous timeout |

---

## 2. Executing `task` steps

### 2a. `PROGRAM`
Run `prompt` as a shell command via Bash with `cwd = RECON_FOUNDRY_ROOT`. Substitute env vars
(`${RECON_FOUNDRY_ROOT}`, etc.) — they're exported, so a normal Bash invocation resolves them.
- Honor `allowFailure`: on non-zero exit, log it and continue rather than aborting.
- If `output.capture`: write stdout to `output.save_to` (expand `{timestamp}`). Many steps already redirect
  with `tee`; don't double-write.
- Commands are pinned by the workflow author — **run them as written**. Don't improvise replacements.

### 2b. `CLAUDE_CODE` / `OPENCODE` (agent phases)
The `prompt` typically reads: *"You are provided an agent definition at `./prompts/agent/<name>.md`. Run
exclusively the `<name>` agent using the Task tool."*

1. Extract `<name>` by matching `./(?:\.opencode|prompts)/agents?/<name>.md` in the `prompt`
   (upstream `core/task.py` uses exactly this regex).
2. Read `framework/prompts/agent/<name>.md`. **Strip the YAML frontmatter** (everything up to and including
   the second `---`); the body after it is the agent instruction.
   - **Name-drift fallback (important):** if `<name>.md` does not exist, the upstream workflow author and
     the vendored file disagree on token order/version suffix — resolve to the best match in
     `framework/prompts/agent/` by the phase identifier and the agent name stated in the instruction
     ("Run exclusively the `<agent>` agent"). The known cases (all in
     `workflow-properties-efficient-v4.0-claude.json`) map as:
     `properties-phase-0-v4`→`properties-v4-phase-0`, `properties-phase-1a-v4`→`properties-v4-phase-1a`,
     `properties-phase-1b-v3.4`→`properties-v4-phase-1b`, `properties-phase-2-v4`→`properties-v4-phase-2`,
     `properties-phase-3a-v4`→`properties-v4-phase-3a`, `properties-phase-3b-v3.4`→`properties-v4-phase-3b`.
     Generally: drop the trailing `-vN[.N]` version suffix and reorder `properties-phase-<X>` ↔
     `properties-v4-phase-<X>`. Never fall back to running the raw one-line prompt as if the agent body were
     empty — always locate and use the real phase file.
3. **Dispatch the body as a `general-purpose` subagent via the Task tool.** Prepend context: the subagent
   works in the target repo at `RECON_FOUNDRY_ROOT`; `PROMPTS_DIR` resolves to
   `~/.claude/skills/recon-magic/framework/prompts` (so any `${PROMPTS_DIR}/styleguide.md`,
   `clamping-handler-rules.md`, `invariant-workshop.md`, `objective-coverage.md`, `audit-template.md`
   references resolve there). A fresh subagent per phase mirrors upstream's per-phase `claude -p`.
4. If the `prompt` is a plain inline instruction (no `agent/<name>.md` reference — e.g. the "Fix Import
   Collisions" step), execute it directly instead of loading an agent file.

> `CLAUDE_CODE` vs `OPENCODE` differ only in which CLI upstream shells out to. Here both mean "run this agent
> phase" — execute identically.

### 2c. `DISPATCH_FUZZING_JOB`
Upstream hands the suite to Recon Pro cloud fuzzing (`framework/core/task.py` `FuzzJobConfig`). Locally:
run the fuzzer directly (echidna/medusa with the job's contract/config/timeout), **or**, if a long cloud
campaign is intended, report it as a manual/cloud handoff and stop. Treat as `allowFailure`.

---

## 3. Executing `decision` steps

Shape: `{ type:"decision", name, mode, modeInfo:{...}, decision:[ {operator,value,action,destinationStep?} ], model? }`.

**Step A — compute the actual value per `mode`:**

| `mode` | `modeInfo` fields | Actual value |
|---|---|---|
| `FILE_EXISTS` | `fileName` (glob, relative to base path) | `1` if any match, else `0` |
| `FILE_CONTAINS` | `fileName`, `searchString` | `1` if first match contains the string, else `0` |
| `READ_FILE` | `fileName` | file's text parsed as a number; unparseable/missing → **CONTINUE** |
| `JSON_KEY_VALUE` | `fileName` (path or glob), `keyPath` (dotted, e.g. `summary.count`) | value at that key (string or number); missing/error → **CONTINUE** |
| `GREP` | `pattern`, `file` (glob) | total `grep -c` match count across matched files |
| `SHELL` | `command` | the command's exit code (run with `cwd = RECON_FOUNDRY_ROOT`) |
| `USE_MODEL` | `prompt` (+ step `model`) | you decide the value by reasoning over the prompt; pick one of the `decision[].value`s |
| `READ_FILE_WITH_MODEL_DIGEST` | `fileName`, `prompt` (+ step `model`) | read the file, then reason over `prompt + contents`; pick a `decision[].value` |

**Step B — match `decision[]` in order** and take the first whose `operator` holds between the actual value
and `value`. Operators: `eq, neq, gt, lt, gte, lte` (numeric when both sides parse as numbers, else string
`eq`/`neq`). If none match → default **CONTINUE**.

**Step C — apply the matched `action`:**

| `action` | Effect |
|---|---|
| `CONTINUE` (default) | go to next step |
| `CONTINUE_WITH_WARNING` | continue; note the warning |
| `STOP` | halt the workflow (success-stop, e.g. critical issue found / nothing left to do) |
| `JUMP_TO_STEP` | jump to the step named in `destinationStep` (forward or backward) |
| `REPEAT_PREVIOUS_STEP` | re-run the immediately preceding step |

**Loop hardcap (= 5):** track how many times each decision step has executed. Once a decision step has run
**5** times, force `CONTINUE` regardless of the gate, so backward jumps / repeats can't loop forever.
(Coverage and echidna-retry workflows use explicit `*-retry-counter` PROGRAM steps + a `READ_FILE` gate as a
second bound — respect those counters too.)

---

## 4. Preconditions & gates

`framework/workflows/workflow-gates.json` defines reusable named gates (e.g. `forge-build-gate`). A step's
`preconditions: ["forge-build-gate", …]` means: evaluate each named gate **before** running the step; if a
gate fails, skip/stop per the gate definition. A gate is essentially a decision evaluated as a guard. Read
`workflow-gates.json` to see each gate's `mode`/`modeInfo`. A precondition naming a gate absent from that
file is an error — report it rather than silently continuing.

---

## 5. Composition (`workflow`-type steps)

A step `{ "type":"workflow", "workflow_file": "<file>.json" }` means **inline that workflow's steps here**.
Before executing, recursively flatten: replace each `workflow` step with the referenced file's steps (load
from `framework/workflows/`). The `compose-*.json` files are thin shells that chain
scout → setup → coverage → properties this way. Flatten first, then run the combined step list as one
workflow.

---

## 6. Execution report

For each step, report: index, name, type/model, and outcome (exit code / PASS-FAIL / files written / gate
result + chosen action). At the end, summarize: steps run, gates hit, artifacts produced (`magic/*.json`,
scaffolding, properties, tests), and whether the workflow reached its terminal step or stopped early.
