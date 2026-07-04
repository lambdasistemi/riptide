#!/usr/bin/env bash
set -euo pipefail

nix develop .#frontend -c just test
nix build .#frontend
nix develop -c just unit
