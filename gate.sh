#!/usr/bin/env bash
set -euo pipefail

nix build .#frontend
nix develop -c just unit
