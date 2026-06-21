# Tools & Dependencies

`PROGRAM` steps in the fuzzing/coverage/setup workflows call CLI tools. Some are **bundled** (the 11 Python
tools under `framework/tools/`, installed by `scripts/preflight.sh`); the rest are **external** and must be
on `PATH`.

---

## Bundled CLI tools (`framework/tools/`)

Pure-stdlib Python (deps: only `pydantic`/`python-dotenv`/`requests` at the package level; the tools
themselves import nothing third-party). Installed as console scripts by `preflight.sh`.

| Command | Source | Purpose | Used by |
|---|---|---|---|
| `extract-target-functions` | `tools/targeted_functions/` | List all fuzz handler/target functions from the scaffolded suite → `magic/target-functions.json` | setup, coverage |
| `filter-build-info` | `tools/filter_build_info/` | Strip sources lacking AST (foundry-pp files) from `out/build-info/*.json` so `sol-expand` won't choke | setup, coverage |
| `touched-function-identifier` | `tools/touched_function_identifier/` | From sol-expand context + target functions, compute every function that must be covered → `magic/functions-to-cover.json` | coverage |
| `order-prerequisite-func` | `tools/order_prerequisite_func/` | Sort handlers by prerequisite count for testing order → `magic/function-sequences-sorted.json` | setup |
| `merge-paths-prerequisites` | `tools/merge_paths_prerequisites/` | Merge non-reverting paths with prerequisite data for sequence building | coverage |
| `covg-eval` | `tools/covg_eval/` | Compare `magic/functions-to-cover.json` against echidna coverage → `magic/functions-missing-covg-{timestamp}.json` (only if gaps) | coverage |
| `covg-scoring` | `tools/covg_scoring/` | Score & sort uncovered functions by complexity to prioritize work | coverage |
| `get-latest-coverage` | `tools/get_latest_coverage/` | Resolve/symlink the latest echidna coverage report | coverage |
| `update-coverage-groups` | `tools/update_coverage_groups/` | Update function-group coverage bookkeeping across iterations | coverage |
| `analyze-echidna-output` | `tools/analyze_echidna_output/` | Parse an echidna run for failures/broken properties/errors | coverage, fuzz |
| `save-echidna-logs` | `tools/save_echidna_logs/` | Persist echidna run logs into the repo for later inspection | coverage, fuzz |

Each has `--help`. Several also carry their own `pyproject.toml` (`covg_eval`, `covg_scoring`,
`filter_build_info`, `merge_paths_prerequisites`, `update_coverage_groups`) so they can be installed
standalone if needed.

---

## External dependencies (must be on `PATH`)

| Tool | Needed for | Install |
|---|---|---|
| `forge` (Foundry) | building, testing, build-info | https://getfoundry.sh |
| `echidna` | property/coverage fuzzing | https://github.com/crytic/echidna |
| `medusa` | alternative coverage fuzzer | https://github.com/crytic/medusa |
| `sol-expand` | extract contract context from build-info (coverage) | Recon tool — install separately; coverage's context step needs it |
| `npx` / `node` | runs `npx recon-generate@latest` (scaffolding, `link2` library linking) | https://nodejs.org |
| `jq` | several setup PROGRAM steps parse `magic/*.json` | `apt install jq` / `brew install jq` |
| `uv` | installs the bundled tools (preflight) | https://github.com/astral-sh/uv |
| `python3` | runs the bundled tools | system |

`preflight.sh` reports which of these are present. Setup/coverage/properties need the fuzzing stack;
`audit` needs essentially none of it.

---

## `magic/` artifact formats

```jsonc
// magic/target-functions.json
{ "target_functions": [ { "contract": "C", "function": "f", "signature": "f(uint256)" } ] }

// magic/functions-to-cover.json
{ "functions_to_cover": [ { "contract":"C","function":"f","signature":"f(uint256)","source_file":"src/C.sol" } ] }

// magic/functions-missing-covg-{timestamp}.json   (created only when gaps remain)
{ "missing_coverage": [ { "contract":"C","function":"f","signature":"f(uint256)","reason":"…" } ],
  "timestamp": "2025-12-04T10:30:00Z" }
```
Scouting writes `magic/contracts-to-scaffold.json` (`source_contracts`, `mocked_contracts`) and
`magic/setup-config-spec.json`; setup writes `magic/function-sequences.json` (+ `…-sorted.json`) and
`admin-functions.json`. See `framework/workflow-io-specification.md` for the full coverage I/O spec.

---

## Why `{timestamp}` and sentinel files matter
- PROGRAM steps with `output.save_to` containing `{timestamp}` expect a fresh UTC stamp each run; the
  coverage gate then globs `functions-missing-covg-*.json` to detect remaining gaps.
- Phases signal control flow by **writing files** the next decision step reads: `CRITICAL_STOP.md`,
  `COMPILATION_FAILED.md` / `COMPILATION_SUCCESS.md`, `FUZZING_SETUP_COMPLETE.md`, echidna exit-code files.
  Don't delete these mid-workflow — gates depend on them.
