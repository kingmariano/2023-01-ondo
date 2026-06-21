# recon-magic (Claude Code skill)

A self-contained Claude Code skill port of **[`Recon-Fuzz/recon-magic-framework`](https://github.com/Recon-Fuzz/recon-magic-framework)**
— an LLM workflow-automation framework for smart-contract fuzzing harness setup, coverage, invariant/property
generation, scouting, unit tests, and naive audits on Foundry repos.

## The work-around (how this is a "skill")

Upstream, a Python engine (`main.py`/`cli.py`/`worker.py`) reads a JSON **workflow** and shells out to
`claude -p` / `opencode` once per phase, evaluating decision gates between phases. That external orchestrator
can't live inside a Claude skill — so **this skill makes Claude Code itself the engine.** `SKILL.md` +
`reference/engine.md` teach Claude to read the same workflow JSON and the same agent prompts (vendored under
`framework/`) and execute the steps directly:

- `task` + `PROGRAM` → run the command via **Bash** at the Foundry root
- `task` + `CLAUDE_CODE`/`OPENCODE` → read `framework/prompts/agent/<name>.md`, strip frontmatter, and
  **dispatch it as a Task-tool subagent** (fresh per-phase context, mirroring upstream's per-phase `claude -p`)
- `decision` → evaluate the gate (8 modes) and branch `STOP`/`CONTINUE`/`JUMP_TO_STEP`/`REPEAT_PREVIOUS_STEP`,
  with a loop hardcap of 5

Nothing is rewritten or summarized away: all 32 workflows, 75 agent prompts, the reference guides, and the 11
CLI tools are vendored verbatim under `framework/`. The authored layer (`SKILL.md`, `reference/`, `scripts/`)
only wraps them.

## Layout

```
recon-magic/
├── SKILL.md              # entry point: dispatcher + native-engine semantics
├── README.md             # this file
├── reference/
│   ├── engine.md         # full step/decision schema → execution checklist for Claude-as-engine
│   ├── catalog.md        # every workflow family: entry file, phases, magic/ artifact flow, "use when"
│   └── tools.md          # the 11 bundled tools, external deps, magic/*.json formats
├── scripts/preflight.sh  # installs the 11 bundled tools as PATH wrappers; reports external deps
└── framework/            # vendored upstream (workflows/, prompts/, tools/, core/, …) minus .git
```

## Use

```
# one-time
bash ~/.claude/skills/recon-magic/scripts/preflight.sh

# then, from a Foundry target repo, ask Claude e.g.:
#   "use recon-magic to set up a fuzzing harness"   (workflow-fuzzing-setup-v2)
#   "run the recon-magic coverage workflow"         (workflow-fuzzing-coverage)
#   "generate invariants with recon-magic"          (workflow-properties-efficient-v4.0-claude)
```
Claude picks the entry workflow (see `SKILL.md` §1), announces the phase plan, and executes it step by step.
Standard order: **scouting → setup → coverage → properties**.

## Notes & differences from upstream

- **No auto-commit by default.** Upstream commits after most steps; this skill leaves git alone unless you say
  "commit" (then it commits steps flagged `shouldCommitChanges`, never pushes).
- **Tools install as wrappers, not a package.** The 11 tools are self-contained stdlib scripts; `preflight.sh`
  drops `python3` wrapper shims in `~/.local/bin` (override with `RECON_MAGIC_BIN`). This avoids the framework's
  `requires-python>=3.12` gate and any build hooks. To install them as real console scripts instead, you can
  `uv tool install --editable ~/.claude/skills/recon-magic/framework`.
- **`DISPATCH_FUZZING_JOB`** upstream hands off to Recon Pro cloud fuzzing; locally it means "run the fuzzer"
  (echidna/medusa) or a manual handoff.
- `sol-expand` (coverage context extraction) is a separate Recon tool — install it yourself if you run the
  coverage workflow.

## Attribution & license

Upstream: **Recon-Fuzz / recon-magic-framework**, licensed **GPL-2.0**. This skill vendors that project
verbatim under `framework/` and adds a thin orchestration layer; the GPL-2.0 terms apply to the vendored code.
All credit for the framework, workflows, and prompts goes to the Recon team.
