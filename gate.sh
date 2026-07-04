#!/usr/bin/env bash
set -euo pipefail

nix build --quiet .#riptide
nix develop --quiet -c just unit
nix develop --quiet -c just format-check
nix develop --quiet -c just hlint
