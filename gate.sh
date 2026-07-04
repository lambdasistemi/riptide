#!/usr/bin/env bash
set -euo pipefail

nix develop -c just unit
nix build .#riptide
nix develop -c just format-check
nix develop -c just hlint
nix develop .#frontend -c just test
nix build .#frontend
