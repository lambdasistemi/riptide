#!/usr/bin/env bash
set -euo pipefail

nix develop --quiet -c just build
nix develop --quiet -c just unit
nix develop --quiet -c just format-check
nix develop --quiet -c just hlint
nix build --quiet .#frontend
nix develop --quiet .#frontend -c just lint
nix develop --quiet .#frontend -c just test
