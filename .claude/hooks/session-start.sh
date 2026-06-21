#!/bin/bash
# SessionStart hook: provision Foundry (forge), solc compilers, git submodules
# and node dependencies so `forge build` works in Claude Code on the web.
set -euo pipefail

# Only run in the remote (web) environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$REPO_DIR"

FOUNDRY_BIN="$HOME/.foundry/bin"

# 1. Install Foundry (forge/cast/anvil/chisel).
# foundry.paradigm.xyz is not on the network allowlist, so fetch release
# binaries directly from GitHub instead of using foundryup.
if [ ! -x "$FOUNDRY_BIN/forge" ]; then
  mkdir -p "$FOUNDRY_BIN"
  curl -sSL --retry 3 --max-time 300 \
    -o /tmp/foundry.tar.gz \
    "https://github.com/foundry-rs/foundry/releases/download/stable/foundry_stable_linux_amd64.tar.gz"
  tar xzf /tmp/foundry.tar.gz -C "$FOUNDRY_BIN"
  rm -f /tmp/foundry.tar.gz
fi
export PATH="$FOUNDRY_BIN:$PATH"

# Persist forge on PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FOUNDRY_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 2. Pre-seed solc compilers into the svm cache.
# binaries.soliditylang.org is not on the network allowlist, so download the
# required solc versions from GitHub releases (matches foundry.toml sources).
for v in 0.8.16 0.6.12 0.5.17; do
  out="$HOME/.svm/$v/solc-$v"
  if [ ! -x "$out" ]; then
    mkdir -p "$HOME/.svm/$v"
    curl -sSL --retry 3 --max-time 300 \
      -o "$out" \
      "https://github.com/ethereum/solidity/releases/download/v$v/solc-static-linux"
    chmod +x "$out"
  fi
done

# 3. Initialize git submodules (forge-std + ds-test).
git submodule update --init --recursive

# 4. Install node dependencies (provides @openzeppelin/@uniswap remappings).
# --ignore-engines: hardhat pins older Node; --ignore-optional skips the
# native sqlite3 build (optional, fails to compile under Node 22).
yarn install --frozen-lockfile --ignore-engines --ignore-optional

echo "Foundry + dependencies ready. Run: forge build"
