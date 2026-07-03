# shellcheck shell=bash

set unstable := true

# List available recipes
default:
    @just --list

# Build all components
build:
    #!/usr/bin/env bash
    set -euo pipefail
    cabal build all --enable-tests -O0

# Run unit tests with optional match pattern
unit match="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ '{{ match }}' == "" ]]; then
        cabal test unit-tests --test-show-details=direct -O0
    else
        cabal test unit-tests --test-show-details=direct -O0 \
            --test-option=--match --test-option="{{ match }}"
    fi

# Format Haskell, Cabal, and Nix files
format:
    #!/usr/bin/env bash
    set -euo pipefail
    for _ in 1 2 3; do fourmolu -i src app test; done
    cabal-fmt -i *.cabal
    nixfmt *.nix

# Check formatting (used by CI)
format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    fourmolu -m check src app test
    cabal-fmt -c *.cabal

# Run hlint
hlint:
    #!/usr/bin/env bash
    set -euo pipefail
    hlint src app test

# cabal check (Hackage-readiness)
cabal-check:
    #!/usr/bin/env bash
    set -euo pipefail
    cabal check \
        --ignore=missing-upper-bounds \
        --ignore=no-modules-exposed \
        --ignore=option-o2

# Full CI pipeline (run inside nix develop)
ci:
    #!/usr/bin/env bash
    set -euo pipefail
    just build
    just unit
    just format-check
    just hlint
