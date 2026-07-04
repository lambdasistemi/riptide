#!/usr/bin/env bash
set -euo pipefail

nix develop --command just build
nix develop --command just unit
nix develop --command just format-check
nix develop --command just hlint
nix build .#frontend
