#!/bin/sh
# The logic tests, with the coverage floor (95 % lines, branches and functions of the code
# they cover). The QML is checked by running it: see doc/DESIGN.md, "Checking it".
set -eu
cd "$(dirname "$0")/.."
exec node --test --experimental-test-coverage \
    --test-coverage-include='tailscale/lib/*.js' \
    --test-coverage-lines=95 --test-coverage-branches=95 --test-coverage-functions=95 \
    tests/*_unit.js
