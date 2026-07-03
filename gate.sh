#!/usr/bin/env bash
set -euo pipefail

nix build .#frontend
test -f result/index.html
test -f result/index.js
nix develop .#frontend -c just lint
