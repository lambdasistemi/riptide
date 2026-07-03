#!/usr/bin/env bash
set -euo pipefail

nix develop .#frontend -c just test
nix develop .#frontend -c purs-tidy check 'src/**/*.purs' 'test/**/*.purs'
nix build .#frontend
