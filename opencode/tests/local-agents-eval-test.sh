#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
nix eval --impure --raw --file "$ROOT/tests/local-agents-eval.nix"
printf '\n'
